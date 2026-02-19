# frozen_string_literal: true

# Unified helpers for progress/notify/alert events in long-running jobs.
module JobNotifiable
  extend ActiveSupport::Concern

  private

  def job_progress(task:, message:, event_id:, payload: {})
    publish_job_event!(task: task, kind: "job_progress", message: message, event_id: event_id, payload: payload)
  end

  def job_notify(task:, message:, event_id:, event_type: "job_notify", ttl: 30.minutes, payload: {})
    create_notification!(task: task, event_type: event_type, message: message, event_id: event_id, ttl: ttl)
    publish_job_event!(task: task, kind: "job_notify", message: message, event_id: event_id, payload: payload)
  end

  def job_alert(task:, message:, event_id:, event_type: "job_alert", ttl: 30.minutes, payload: {})
    create_notification!(task: task, event_type: event_type, message: message, event_id: event_id, ttl: ttl)
    publish_job_event!(task: task, kind: "job_alert", message: message, event_id: event_id, payload: payload)
  end

  def create_notification!(task:, event_type:, message:, event_id:, ttl:)
    return unless task&.user

    Notification.create_deduped!(
      user: task.user,
      task: task,
      event_type: event_type,
      message: message,
      event_id: event_id,
      ttl: ttl
    )
  end

  def publish_job_event!(task:, kind:, message:, event_id:, payload: {})
    OutcomeEventChannel.publish!({
      event_id: event_id,
      kind: kind,
      task_id: task&.id,
      user_id: task&.user_id,
      message: message
    }.merge(payload))
  rescue StandardError => e
    Rails.logger.warn("[JobNotifiable] publish failed: #{e.class}: #{e.message}")
  end
end
