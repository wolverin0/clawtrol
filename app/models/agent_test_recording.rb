# frozen_string_literal: true

class AgentTestRecording < ApplicationRecord
  # Use strict_loading_mode to detect N+1 queries in views
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :agent_test_recordings
  belongs_to :task, optional: true, inverse_of: :agent_test_recordings

  STATUSES = %w[recorded verified failed pending].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: STATUSES }
  validates :session_id, length: { maximum: 100 }
  validates :action_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :verified, -> { where(status: "verified") }
  scope :for_task, ->(task_or_id) { where(task_id: task_or_id.respond_to?(:id) ? task_or_id.id : task_or_id) }
end
