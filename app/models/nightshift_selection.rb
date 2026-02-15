# frozen_string_literal: true

class NightshiftSelection < ApplicationRecord
  belongs_to :nightshift_mission, inverse_of: :nightshift_selections

  STATUSES = %w[pending running completed failed].freeze

  scope :for_tonight, -> { where(scheduled_date: Date.current) }
  scope :enabled, -> { where(enabled: true) }
  scope :pending, -> { where(status: "pending") }
  scope :armed, -> { enabled.pending }

  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: 500 }
  validates :scheduled_date, presence: true
  validates :result, length: { maximum: 100_000 }
  validates :nightshift_mission_id, uniqueness: { scope: :scheduled_date, message: "already has a selection for this date" }
  validate :completed_at_requires_terminal_status
  validate :launched_at_not_in_future

  private

  def completed_at_requires_terminal_status
    if completed_at.present? && !%w[completed failed].include?(status)
      errors.add(:completed_at, "can only be set when status is completed or failed")
    end
  end

  def launched_at_not_in_future
    if launched_at.present? && launched_at > 1.minute.from_now
      errors.add(:launched_at, "cannot be in the future")
    end
  end
end
