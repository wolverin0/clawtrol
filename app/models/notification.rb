class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true

  # Event types
  EVENT_TYPES = %w[
    task_completed
    task_errored
    review_passed
    review_failed
    agent_claimed
    validation_passed
    validation_failed
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :message, presence: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }

  # Mark as read
  def mark_as_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  def read?
    read_at.present?
  end

  def unread?
    read_at.nil?
  end

  # Icon based on event type
  def icon
    case event_type
    when "task_completed", "validation_passed"
      "✅"
    when "task_errored", "validation_failed"
      "❌"
    when "review_passed"
      "🎉"
    when "review_failed"
      "⚠️"
    when "agent_claimed"
      "🤖"
    else
      "🔔"
    end
  end

  # Color class based on event type
  def color_class
    case event_type
    when "task_completed", "review_passed", "validation_passed"
      "text-status-success"
    when "task_errored", "review_failed", "validation_failed"
      "text-status-error"
    when "agent_claimed"
      "text-accent"
    else
      "text-content-secondary"
    end
  end

  # Create a notification for a task status change
  def self.create_for_status_change(task, old_status, new_status)
    return unless task.user

    case new_status
    when "in_review"
      create!(
        user: task.user,
        task: task,
        event_type: "task_completed",
        message: "#{task.name.truncate(50)} is ready for review"
      )
    when "done"
      create!(
        user: task.user,
        task: task,
        event_type: "task_completed",
        message: "#{task.name.truncate(50)} completed"
      )
    end
  end

  # Create a notification for task error
  def self.create_for_error(task, error_message = nil)
    return unless task.user

    create!(
      user: task.user,
      task: task,
      event_type: "task_errored",
      message: "#{task.name.truncate(40)} encountered an error#{error_message.present? ? ": #{error_message.truncate(60)}" : ""}"
    )
  end

  # Create a notification for review result
  def self.create_for_review(task, passed:)
    return unless task.user

    create!(
      user: task.user,
      task: task,
      event_type: passed ? "review_passed" : "review_failed",
      message: "#{task.name.truncate(50)} #{passed ? 'passed review' : 'failed review'}"
    )
  end

  # Create a notification for agent claim
  def self.create_for_agent_claim(task)
    return unless task.user

    create!(
      user: task.user,
      task: task,
      event_type: "agent_claimed",
      message: "Agent started working on #{task.name.truncate(50)}"
    )
  end
end
