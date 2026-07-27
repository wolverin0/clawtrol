# frozen_string_literal: true

class OrchestrationSource < ApplicationRecord
  PROFILE_PATTERN = /\A[A-Za-z0-9._-]+\z/
  STATUSES = %w[healthy degraded stale offline].freeze

  belongs_to :user, inverse_of: :orchestration_sources
  has_many :orchestration_intents, dependent: :destroy, inverse_of: :orchestration_source

  validates :profile, presence: true, length: { maximum: 64 },
    format: { with: PROFILE_PATTERN },
    uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: STATUSES }
  validates :last_error, length: { maximum: 2_000 }, allow_nil: true

  scope :fresh, -> { where("last_seen_at >= ?", 90.seconds.ago) }
  scope :most_recent, -> { order(last_seen_at: :desc, id: :asc) }

  def stale?
    last_seen_at.blank? || last_seen_at < 90.seconds.ago
  end

  def display_status
    stale? ? "stale" : status
  end
end
