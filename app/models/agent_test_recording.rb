# frozen_string_literal: true

class AgentTestRecording < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true

  STATUSES = %w[recorded generated verified failed].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
end
