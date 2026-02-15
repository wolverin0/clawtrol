# frozen_string_literal: true

class NightshiftSelection < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :nightshift_mission, inverse_of: :nightshift_selections

  STATUSES = %w[pending running completed failed].freeze

  scope :for_tonight, -> { where(scheduled_date: Date.current) }
  scope :enabled, -> { where(enabled: true) }
  scope :pending, -> { where(status: "pending") }
  scope :armed, -> { enabled.pending }

  validates :status, inclusion: { in: STATUSES }
end
