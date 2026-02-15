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
end
