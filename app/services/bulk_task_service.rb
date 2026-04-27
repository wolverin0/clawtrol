# frozen_string_literal: true

# Handles bulk task operations: move status, change model, archive, delete.
# Extracted from Boards::TasksController to keep controllers thin.
#
# Usage:
#   result = BulkTaskService.new(
#     board: board,
#     task_ids: [1, 2, 3],
#     action_type: "move_status",
#     value: "done"
#   ).call
#
#   result.success        # => true/false
#   result.error          # => error message (if failed)
#   result.affected_count # => number of tasks affected
#   result.affected_statuses # => ["inbox", "done"] (statuses touched)
class BulkTaskService
  Result = Struct.new(:success, :error, :affected_count, :affected_statuses, keyword_init: true)

  ALLOWED_ACTIONS = %w[move_status change_model archive delete].freeze

  attr_reader :board, :task_ids, :action_type, :value

  def initialize(board:, task_ids:, action_type:, value: nil)
    @board = board
    @task_ids = Array(task_ids).map(&:to_i).reject(&:zero?)
    @action_type = action_type.to_s
    @value = value
  end

  def call
    return Result.new(success: false, error: "No tasks selected") if task_ids.empty?
    return Result.new(success: false, error: "Invalid action: #{action_type}") unless ALLOWED_ACTIONS.include?(action_type)

    # Eager-load every dependent: :destroy association so the destroy
    # callbacks per task hit cached collections instead of issuing an N+1
    # storm. Keep this list aligned with Task model has_many dependent:
    # :destroy declarations.
    tasks = board.tasks.where(id: task_ids).includes(
      :activities, :notifications, :token_usages, :task_diffs, :task_runs,
      :runner_leases, :agent_messages, :agent_activity_events,
      :task_dependencies, :inverse_dependencies
    )
    return Result.new(success: false, error: "No matching tasks found") if tasks.empty?

    affected_statuses = tasks.pluck(:status).uniq

    case action_type
    when "move_status"
      move_status(tasks, affected_statuses)
    when "change_model"
      change_model(tasks, affected_statuses)
    when "archive"
      archive_tasks(tasks, affected_statuses)
    when "delete"
      delete_tasks(tasks, affected_statuses)
    end
  rescue StandardError => e
    Rails.logger.error("[BulkTaskService] #{action_type} failed: #{e.message}")
    Result.new(success: false, error: e.message)
  end

  private

  def move_status(tasks, affected_statuses)
    unless Task.statuses.key?(value)
      return Result.new(success: false, error: "Invalid status: #{value}")
    end

    now = Time.current
    extra = { updated_at: now }
    extra[:completed] = (value == "done")
    extra[:completed_at] = value == "done" ? now : nil
    extra[:archived_at] = value == "archived" ? now : nil

    count = tasks.update_all(extra.merge(status: Task.statuses[value]))

    KanbanChannel.broadcast_refresh(board.id) rescue nil

    affected_statuses << value
    Result.new(success: true, affected_count: count, affected_statuses: affected_statuses.uniq)
  end

  def change_model(tasks, affected_statuses)
    if value.present? && value.to_s.length > 120
      return Result.new(success: false, error: "Invalid model: #{value}")
    end

    count = tasks.update_all(
      model: value.presence,
      updated_at: Time.current
    )

    Result.new(success: true, affected_count: count, affected_statuses: affected_statuses)
  end

  def archive_tasks(tasks, affected_statuses)
    now = Time.current
    count = tasks.update_all(
      status: Task.statuses["archived"],
      archived_at: now,
      completed: false,
      updated_at: now
    )

    KanbanChannel.broadcast_refresh(board.id) rescue nil

    affected_statuses << "archived"
    Result.new(success: true, affected_count: count, affected_statuses: affected_statuses.uniq)
  end

  def delete_tasks(tasks, affected_statuses)
    # Force materialization with the .includes(:activities) preload set on
    # the relation — destroy_all then iterates the loaded array and the
    # dependent: :destroy callback finds activities cached on each task.
    loaded_tasks = tasks.to_a
    count = loaded_tasks.size
    loaded_tasks.each(&:destroy)

    Result.new(success: true, affected_count: count, affected_statuses: affected_statuses)
  end
end
