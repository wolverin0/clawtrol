class NightshiftSelection < ApplicationRecord
  belongs_to :nightshift_mission, optional: true

  scope :for_tonight, -> { where(scheduled_date: Date.current) }
  scope :enabled, -> { where(enabled: true) }
  scope :pending, -> { where(status: 'pending') }
end
