# frozen_string_literal: true

class Session < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :sessions

  # Scopes for common queries
  scope :for_user, ->(user) { where(user: user) if user.present? }
  scope :recent, -> { order(created_at: :desc).limit(50) }

  # Validations
  validates :ip_address, length: { maximum: 255 }
  validates :user_agent, length: { maximum: 500 }
  validates :session_type, length: { maximum: 50 }, inclusion: { in: %w[main cron hook subagent isolated], allow_nil: true }
  validates :status, length: { maximum: 50 }, inclusion: { in: %w[active paused completed error], allow_nil: true }
  validates :identity, length: { maximum: 255 }, allow_nil: true

  # Ensure user_id is present for non-system sessions
  validate :user_required_for_non_system

  private

  def user_required_for_non_system
    return if session_type.nil? || session_type == "system"
    return if user_id.present?

    errors.add(:user_id, "is required for user sessions")
  end
end
