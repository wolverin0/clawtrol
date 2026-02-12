class NightshiftSelection < ApplicationRecord
  scope :for_tonight, -> { where(scheduled_date: Date.current) }
  scope :enabled, -> { where(enabled: true) }
  scope :pending, -> { where(status: 'pending') }
end
