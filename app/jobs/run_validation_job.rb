# frozen_string_literal: true

class RunValidationJob < ApplicationJob
  include TaskBroadcastable

  queue_as :default

  # Don't retry validation — it could re-run expensive commands
  discard_on ActiveRecord::RecordNotFound

  def perform(task_id)
    task = Task.find(task_id)
    return unless task.review_status == "pending" && task.command_review?

    task.update!(review_status: "running")
    broadcast_task_update(task)

    ValidationRunnerService.new(task, timeout: ValidationRunnerService::REVIEW_TIMEOUT).call_as_review

    broadcast_task_update(task)
  rescue StandardError => e
    # Mark review as failed so UI doesn't show perpetual "running"
    task&.complete_review!(
      status: "failed",
      result: { error_summary: "Validation job crashed: #{e.message}" }
    )
    broadcast_task_update(task) if task
    raise # re-raise for ActiveJob retry/discard logic
  end
end
