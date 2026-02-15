# frozen_string_literal: true

# Service for applying bulk actions to a set of tasks on a board.
# Used by Boards::TasksController#bulk_update.
class BulkTaskService
  Result = Struct.new(
    :success,
    :error,
    :affected_count,
    :affected_statuses,
    keyword_init: true
  )

  VALID_ACTIONS = %w[move_status change_model archive delete].freeze

  def initialize(board:, task_ids:, action_type:, value: nil)
    @board = board
    @task_ids = Array(task_ids).map(&:to_i).uniq
    @action_type = action_type.to_s
    @value = value
  end

  def call
    return Result.new(success: false, error: "No tasks selected", affected_count: 0, affected_statuses: []) if @task_ids.empty?
    return Result.new(success: false, error: "Unknown action", affected_count: 0, affected_statuses: []) unless VALID_ACTIONS.include?(@action_type)

    tasks = @board.tasks.where(id: @task_ids)
    return Result.new(success: false, error: "No matching tasks found", affected_count: 0, affected_statuses: []) if tasks.empty?

    affected_statuses = tasks.distinct.pluck(:status)

    case @action_type
    when "move_status"
      new_status = @value.to_s
      begin
        Task.statuses.fetch(new_status)
      rescue KeyError
        return Result.new(success: false, error: "Invalid status", affected_count: 0, affected_statuses: affected_statuses)
      end

      affected = tasks.update_all(status: Task.statuses.fetch(new_status), updated_at: Time.current)
      Result.new(success: true, affected_count: affected, affected_statuses: (affected_statuses + [new_status]).uniq)

    when "change_model"
      # Task model validation already restricts values; keep this permissive here.
      affected = tasks.update_all(model: @value.presence, updated_at: Time.current)
      Result.new(success: true, affected_count: affected, affected_statuses: affected_statuses)

    when "archive"
      affected = tasks.update_all(status: Task.statuses.fetch("archived"), updated_at: Time.current)
      Result.new(success: true, affected_count: affected, affected_statuses: (affected_statuses + ["archived"]).uniq)

    when "delete"
      count = 0
      tasks.find_each do |task|
        task.destroy!
        count += 1
      end
      Result.new(success: true, affected_count: count, affected_statuses: affected_statuses)
    end
  end
end
