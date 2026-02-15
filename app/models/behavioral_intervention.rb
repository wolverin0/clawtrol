# frozen_string_literal: true

class BehavioralIntervention < ApplicationRecord
  belongs_to :user
  belongs_to :audit_report, optional: true

  STATUSES = %w[active resolved regressed].freeze

  validates :rule, presence: true
  validates :category, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :baseline_score, :current_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :resolved, -> { where(status: "resolved") }
  scope :regressed, -> { where(status: "regressed") }

  def resolve!
    update!(status: "resolved", resolved_at: Time.current)
  end

  def regress!
    update!(status: "regressed", regressed_at: Time.current)
  end
end
