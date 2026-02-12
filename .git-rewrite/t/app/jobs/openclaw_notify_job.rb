# frozen_string_literal: true

class OpenclawNotifyJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task

    OpenclawWebhookService.new(task.user).notify_task_assigned(task)
  end
end
