# frozen_string_literal: true

class Session < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :sessions

  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  validates :ip_address, length: { maximum: 255 }, allow_nil: true
  validates :user_agent, length: { maximum: 500 }, allow_nil: true
end
