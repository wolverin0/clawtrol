class RunValidationJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find(task_id)
    return unless task.review_status == "pending" && task.command_review?

    task.update!(review_status: "running")
    broadcast_task_update(task)

    ValidationRunnerService.new(task, timeout: ValidationRunnerService::REVIEW_TIMEOUT).call_as_review

    broadcast_task_update(task)
  end

  private

  def broadcast_task_update(task)
    Turbo::StreamsChannel.broadcast_action_to(
      "board_#{task.board_id}",
      action: :replace,
      target: "task_#{task.id}",
      partial: "boards/task_card",
      locals: { task: task }
    )
  end
end
