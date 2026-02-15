# frozen_string_literal: true

class RunValidationJob < ApplicationJob
  include TaskBroadcastable

  queue_as :default

  def perform(task_id)
    task = Task.find(task_id)
    return unless task.review_status == "pending" && task.command_review?

    task.update!(review_status: "running")
    broadcast_task_update(task)

    ValidationRunnerService.new(task, timeout: ValidationRunnerService::REVIEW_TIMEOUT).call_as_review

    broadcast_task_update(task)
  end
end
