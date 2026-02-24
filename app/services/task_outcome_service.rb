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
    @recommended_action ||= output_contract&.recommended_action || @payload["recommended_action"].to_s.presence || "in_review"
  end

  def summary
    @summary ||= output_contract&.summary || @payload["summary"]
  end

  def contract_changes
    @contract_changes ||= output_contract&.changes || normalize_list(@payload["changes"])
  end

  def contract_validation
    @contract_validation ||= output_contract&.validation || @payload["validation"]
  end

  def contract_follow_up
    @contract_follow_up ||= output_contract&.follow_up || normalize_list(@payload["follow_up"])
  end

  def output_contract
    @output_contract ||= SubAgentOutputContract.from_params(@payload)
  end

  def normalized_payload
    base = @payload.to_h
    contract_payload = output_contract&.to_payload || {}
    merged = base.merge(contract_payload)

    run_tokens = normalized_run_tokens_payload
    return merged unless run_tokens.present?

    run_payload = merged["run"]
    run_payload = {} unless run_payload.is_a?(Hash)
    run_payload["tokens"] = run_tokens
    merged["run"] = run_payload

    merged
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
    status_changed = false

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
        summary: summary,
        achieved: Array(@payload["achieved"]),
        evidence: Array(@payload["evidence"]),
        remaining: Array(@payload["remaining"]),
next_prompt: @payload["next_prompt"],
model_used: @payload["model_used"],
prompt_used: @task.effective_prompt,
follow_up_prompt: @payload["next_prompt"],
        openclaw_session_id: @payload["openclaw_session_id"],
        openclaw_session_key: @payload["openclaw_session_key"],
        raw_payload: normalized_payload
      )

      record_run_tokens!(task_run)

      # Release any runner lease: the run is over

      @task.runner_leases.where(released_at: nil).update_all(released_at: Time.current)
      requeue_same_task = follow_up_requeue_same_task?
      status_target = requeue_same_task ? :up_next : :in_review

      base_updates = {
        run_count: run_number,
        last_run_id: run_id,
        last_outcome_at: ended_at,
        last_needs_follow_up: needs_follow_up,
        last_recommended_action: recommended_action,
        agent_claimed_at: nil,
        agent_session_id: nil,
        agent_session_key: nil,
        status: status_target
      }

      if requeue_same_task
        base_updates[:assigned_to_agent] = true
        base_updates[:assigned_at] = Time.current
# P0 dual-write: also persist follow_up_prompt on the TaskRun
task_run.update_columns(follow_up_prompt: @payload["next_prompt"]) if @payload["next_prompt"].present?
      end

      @task.update!(base_updates)
      status_changed = @task.saved_change_to_status?
    end

    unless idempotent
      sync_pipeline_stage_for_outcome!
      broadcast_update(old_status)
      notify_outcome_reported!(task_run, status_changed: status_changed)
      publish_outcome_event!(task_run)
    end

    Result.new(success: true, idempotent: idempotent, task_run: task_run, task: @task)
  end

  def sync_pipeline_stage_for_outcome!
    return unless @task.pipeline_enabled?

    target_stage = case @task.status.to_s
    when "in_progress" then "executing"
    when "up_next"
      (@task.routed_model.present? && @task.compiled_prompt.present?) ? "routed" : "unstarted"
    when "in_review" then "verifying"
    when "done", "archived" then "completed"
    else nil
    end

    return if target_stage.blank? || @task.pipeline_stage.to_s == target_stage

    log = Array(@task.pipeline_log)
    log << {
      stage: "pipeline_sync",
      from: @task.pipeline_stage,
      to: target_stage,
      source: "task_outcome",
      at: Time.current.iso8601
    }

    @task.update_columns(pipeline_stage: target_stage, pipeline_log: log, updated_at: Time.current)
    @task.reload
  rescue StandardError => e
    Rails.logger.warn("[TaskOutcomeService] Pipeline sync failed for task_id=#{@task.id}: #{e.message}")
  end

  def notify_outcome_reported!(task_run, status_changed:)
    needs_follow_up_text = task_run&.needs_follow_up? ? "YES" : "NO"
    action_text = task_run&.recommended_action.to_s.presence || "in_review"
    summary_text = task_run&.summary.to_s.truncate(100)

    message = "Outcome reported for ##{@task.id}: follow-up #{needs_follow_up_text} (#{action_text})"
    message = "#{message} — #{summary_text}" if summary_text.present?

    Notification.create_deduped!(
      user: @task.user,
      task: @task,
      event_type: "task_outcome_reported",
      message: message,
      event_id: "task_outcome_reported:#{run_id}"
    )

    # If status did not change (already in_review), create_for_status_change won't fire,
    # so we send an explicit external notification here.
    unless status_changed
      ExternalNotificationService.new(@task).notify_task_completion
    end

    OriginDeliveryService.new(@task, task_run: task_run).deliver_outcome!
  rescue StandardError => e
    Rails.logger.warn("[TaskOutcomeService] Outcome notification failed task_id=#{@task.id}: #{e.message}")
  end

def follow_up_requeue_same_task?
  needs_follow_up && recommended_action == "requeue_same_task"
end


  def publish_outcome_event!(task_run)
    resolution = DeliveryTargetResolver.resolve(@task)

    OutcomeEventChannel.publish!({
      event_id: run_id,
      kind: "task_outcome",
      task_id: @task.id,
      task_run_id: task_run.id,
      user_id: @task.user_id,
      status: @task.status,
      summary: task_run.summary,
      changes: contract_changes,
      validation: contract_validation,
      follow_up: contract_follow_up,
      recommended_action: task_run.recommended_action,
      needs_follow_up: task_run.needs_follow_up?,
      origin_chat_id: @task.origin_chat_id,
      origin_thread_id: @task.origin_thread_id,
      origin_session_id: @task.origin_session_id,
      origin_session_key: @task.origin_session_key,
      delivery_channel: resolution.channel.to_s,
      delivery_reason: resolution.reason,
      delivery_source: resolution.source,
      delivery_target: resolution.to_h
    })
  rescue StandardError => e
    Rails.logger.warn("[TaskOutcomeService] Outcome event publish failed task_id=#{@task.id}: #{e.message}")
  end

def normalized_run_tokens_payload
  tokens = run_tokens_contract
  return nil unless tokens

  {
    "input_tokens" => tokens[:input_tokens],
    "output_tokens" => tokens[:output_tokens],
    "cache_read_tokens" => tokens[:cache_read_tokens],
    "cache_write_tokens" => tokens[:cache_write_tokens],
    "model" => tokens[:model],
    "cost_usd" => tokens[:cost]
  }.compact
end

def run_tokens_contract
  @run_tokens_contract ||= begin
    source = @payload["run"]
    source = source["tokens"] if source.is_a?(Hash)
    source ||= @payload["tokens"]
    source ||= @payload["usage"]

    return nil unless source.respond_to?(:to_h)

    raw = source.to_h.with_indifferent_access
    input_tokens = raw[:input_tokens] || raw[:input] || raw[:prompt_tokens]
    output_tokens = raw[:output_tokens] || raw[:output] || raw[:completion_tokens]
    cache_read_tokens = raw[:cache_read_tokens] || raw[:cache_read]
    cache_write_tokens = raw[:cache_write_tokens] || raw[:cache_write]
    cost = raw[:cost_usd] || raw[:cost]

    normalized = {
      input_tokens: input_tokens.to_i,
      output_tokens: output_tokens.to_i,
      cache_read_tokens: cache_read_tokens.to_i,
      cache_write_tokens: cache_write_tokens.to_i,
      model: raw[:model].presence || @payload["model_used"].presence || @task.model,
      cost: cost.present? ? cost.to_f : nil,
      session_key: @payload["openclaw_session_key"].presence || @task.agent_session_key
    }

    has_signal = normalized[:input_tokens].positive? || normalized[:output_tokens].positive? || normalized[:cost].present?
    has_signal ? normalized : nil
  rescue StandardError => e
    Rails.logger.warn("[TaskOutcomeService] Could not parse run.tokens for task_id=#{@task.id}: #{e.message}")
    nil
  end
end

def record_run_tokens!(task_run)
  tokens = run_tokens_contract
  return unless tokens

  usage = TokenUsage.create!(
    task: @task,
    agent_persona_id: @task.agent_persona_id,
    model: tokens[:model].presence || @task.model.presence || "unknown",
    input_tokens: tokens[:input_tokens].to_i,
    output_tokens: tokens[:output_tokens].to_i,
    session_key: tokens[:session_key]
  )

  usage.update_column(:cost, tokens[:cost].to_f.round(6)) if tokens[:cost].present?

  return unless task_run.raw_payload.is_a?(Hash)

  run_payload = task_run.raw_payload["run"]
  run_payload = {} unless run_payload.is_a?(Hash)
  run_payload["tokens"] = normalized_run_tokens_payload if normalized_run_tokens_payload
  task_run.update_column(:raw_payload, task_run.raw_payload.merge("run" => run_payload))
rescue StandardError => e
  Rails.logger.warn("[TaskOutcomeService] token recording failed for task_id=#{@task.id}: #{e.message}")
end

  def normalize_list(value)
    case value
    when Array
      value.map(&:to_s).map(&:strip).reject(&:blank?)
    when String
      value.lines.map(&:strip).reject(&:blank?)
    else
      []
    end
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
