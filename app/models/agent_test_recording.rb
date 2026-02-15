# frozen_string_literal: true

class AgentTestRecording < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :agent_test_recordings
  belongs_to :task, optional: true, inverse_of: :task

  STATUSES = %w[recorded generated verified failed].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
end
