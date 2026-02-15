# frozen_string_literal: true

class NightshiftSelection < ApplicationRecord
  belongs_to :nightshift_mission, inverse_of: :nightshift_selections

  STATUSES = %w[pending running completed failed].freeze

  scope :for_tonight, -> { where(scheduled_date: Date.current) }
  scope :enabled, -> { where(enabled: true) }
  scope :pending, -> { where(status: "pending") }
  scope :armed, -> { enabled.pending }

  validates :status, inclusion: { in: STATUSES }
end
