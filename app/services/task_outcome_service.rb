# frozen_string_literal: true

# TaskOutcomeService processes agent task outcome reports.
#
# Extracted from HooksController#task_outcome to keep the controller thin.
# Handles: payload validation, TaskRun creation (idempotent), lease release,
# status transitions, and kanban broadcast.
#
# Usage:
#   result = TaskOutcomeService.call(task, payload)
#   result.success?        # true/false
#   result.idempotent?     # true if this run_id was already processed
#   result.task_run        # the created/existing TaskRun
#   result.error           # error message if failed
#   result.error_status    # HTTP status symbol if failed
#
class TaskOutcomeService
  Result = Struct.new(:success, :idempotent, :task_run, :task, :error, :error_status, keyword_init: true) do
    def success? = success
    def idempotent? = !!idempotent
  end

  REQUIRED_VERSION = "1"
  RUN_ID_PATTERN = /\A[0-9a-fA-F\-]{36}\z/

  # @param task [Task]
  # @param payload [Hash] permitted params
  # @return [Result]
  def self.call(task, payload)
    new(task, payload).call
  end

  def initialize(task, payload)
    @task = task
    @payload = payload.to_h.with_indifferent_access
  end

  def call
    error = validate_payload
    return error if error

    # Idempotency: check before acquiring lock
    existing = TaskRun.find_by(run_id: run_id)
    if existing
      return Result.new(success: true, idempotent: true, task_run: existing, task: @task)
    end

    process_outcome
  rescue ActiveRecord::RecordNotUnique
    existing = TaskRun.find_by(run_id: run_id)
    Result.new(success: true, idempotent: true, task_run: existing, task: @task)
  end

  private

  def run_id
    @payload["run_id"].to_s
  end

  def ended_at
    @ended_at ||= begin
      raw = @payload["ended_at"].to_s
      raw.present? ? Time.iso8601(raw) : Time.current
    rescue StandardError
      Time.current
    end
  end

  def needs_follow_up
    @needs_follow_up ||= ActiveModel::Type::Boolean.new.cast(@payload["needs_follow_up"]) || false
  end

  def recommended_action
    @recommended_action ||= @payload["recommended_action"].to_s.presence || "in_review"
  end

  def validate_payload
    unless @payload["version"].to_s == REQUIRED_VERSION
      return Result.new(success: false, task: @task, error: "invalid version", error_status: :unprocessable_entity)
    end

    unless run_id.match?(RUN_ID_PATTERN)
      return Result.new(success: false, task: @task, error: "invalid run_id", error_status: :unprocessable_entity)
    end

    unless TaskRun::RECOMMENDED_ACTIONS.include?(recommended_action)
      return Result.new(success: false, task: @task, error: "invalid recommended_action", error_status: :unprocessable_entity)
    end

    if needs_follow_up && recommended_action == "requeue_same_task" && @payload["next_prompt"].to_s.blank?
      return Result.new(success: false, task: @task, error: "next_prompt required for requeue_same_task", error_status: :unprocessable_entity)
    end

    nil # valid
  end

  def process_outcome
    task_run = nil
    idempotent = false
    old_status = @task.status

    Task.transaction do
      @task.lock!

      # Re-check under lock for race conditions
      task_run = TaskRun.find_by(run_id: run_id)
      if task_run
        idempotent = true
        next
      end

      run_number = @task.run_count.to_i + 1

      task_run = TaskRun.create!(
        task: @task,
        run_id: run_id,
        run_number: run_number,
        ended_at: ended_at,
        needs_follow_up: needs_follow_up,
        recommended_action: recommended_action,
        summary: @payload["summary"],
        achieved: Array(@payload["achieved"]),
        evidence: Array(@payload["evidence"]),
        remaining: Array(@payload["remaining"]),
        next_prompt: @payload["next_prompt"],
        model_used: @payload["model_used"],
        openclaw_session_id: @payload["openclaw_session_id"],
        openclaw_session_key: @payload["openclaw_session_key"],
        raw_payload: @payload
      )

      # Release any runner lease: the run is over
      @task.runner_leases.where(released_at: nil).update_all(released_at: Time.current)

      base_updates = {
        run_count: run_number,
        last_run_id: run_id,
        last_outcome_at: ended_at,
        last_needs_follow_up: needs_follow_up,
        last_recommended_action: recommended_action,
        agent_claimed_at: nil,
        status: :in_review
      }

      @task.update!(base_updates)
    end

    # Broadcast kanban update outside the transaction
    broadcast_update(old_status) unless idempotent

    Result.new(success: true, idempotent: idempotent, task_run: task_run, task: @task)
  end

  def broadcast_update(old_status)
    KanbanChannel.broadcast_refresh(
      @task.board_id,
      task_id: @task.id,
      action: "update",
      old_status: old_status,
      new_status: @task.status
    )
  rescue StandardError => e
    Rails.logger.warn("[TaskOutcomeService] Broadcast failed: #{e.message}")
  end
end
