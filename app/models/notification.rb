# frozen_string_literal: true

class Notification < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :notifications
  belongs_to :task, optional: true, inverse_of: :task

  DEDUP_WINDOW = 5.minutes
  CAP_PER_USER = 200

  # Event types
  EVENT_TYPES = %w[
    task_completed
    task_errored
    review_passed
    review_failed
    agent_claimed
    validation_passed
    validation_failed
    auto_runner
    auto_runner_error
    auto_pull_claimed
    auto_pull_ready
    auto_pull_spawned
    auto_pull_error
    zombie_task
    zombie_detected
    runner_lease_expired
    runner_lease_missing
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :message, presence: true, length: { maximum: 10_000 }
  validates :read_at, presence: true, if: -> { persisted? && read_at.present? }

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }
  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :unread_count, -> { unread.count }

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
    when "agent_claimed", "auto_runner", "auto_pull_claimed", "auto_pull_ready", "auto_pull_spawned"
      "🤖"
    when "auto_runner_error", "auto_pull_error"
      "❌"
    when "zombie_task", "zombie_detected"
      "🧟"
    when "runner_lease_expired", "runner_lease_missing"
      "🏷️"
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
    when "agent_claimed", "auto_runner", "auto_pull_claimed", "auto_pull_ready", "auto_pull_spawned"
      "text-accent"
    when "auto_runner_error", "auto_pull_error"
      "text-status-error"
    when "zombie_task", "zombie_detected"
      "text-status-error"
    when "runner_lease_expired", "runner_lease_missing"
      "text-status-warning"
    else
      "text-content-secondary"
    end
  end

  # Create a notification for a task status change
  def self.create_for_status_change(task, old_status, new_status)
    return unless task.user

    case new_status
    when "in_review"
      create_deduped!(
        user: task.user,
        task: task,
        event_type: "task_completed",
        message: "#{task.name.truncate(50)} is ready for review"
      )
      ExternalNotificationService.new(task).notify_task_completion
    when "done"
      create_deduped!(
        user: task.user,
        task: task,
        event_type: "task_completed",
        message: "#{task.name.truncate(50)} completed"
      )
      ExternalNotificationService.new(task).notify_task_completion
    end
  end

  # Create a notification for task error
  def self.create_for_error(task, error_message = nil)
    return unless task.user

    create_deduped!(
      user: task.user,
      task: task,
      event_type: "task_errored",
      message: "#{task.name.truncate(40)} encountered an error#{error_message.present? ? ": #{error_message.truncate(60)}" : ""}"
    )
  end

  # Create a notification for review result
  def self.create_for_review(task, passed:)
    return unless task.user

    create_deduped!(
      user: task.user,
      task: task,
      event_type: passed ? "review_passed" : "review_failed",
      message: "#{task.name.truncate(50)} #{passed ? 'passed review' : 'failed review'}"
    )
  end

  # Create a notification for agent claim
  def self.create_for_agent_claim(task)
    return unless task.user

    create_deduped!(
      user: task.user,
      task: task,
      event_type: "agent_claimed",
      message: "Agent started working on #{task.name.truncate(50)}"
    )
  end

  # Safe default for noisy event streams (auto-runner, background jobs).
  # Returns the notification or nil when deduped.
  def self.create_deduped!(user:, event_type:, message:, task: nil)
    return nil unless user

    scope = where(user_id: user.id, event_type: event_type)
    scope = scope.where(task_id: task.id) if task
    scope = scope.where("created_at >= ?", DEDUP_WINDOW.ago)
    return nil if scope.exists?

    create!(user: user, task: task, event_type: event_type, message: message)
  end

  def self.enforce_cap_for_user_id!(user_id)
    overflow_ids = where(user_id: user_id).order(created_at: :desc).offset(CAP_PER_USER).pluck(:id)
    where(id: overflow_ids).delete_all if overflow_ids.any?
  end

  private

  def enforce_cap_for_user
    self.class.enforce_cap_for_user_id!(user_id)
  end
end
