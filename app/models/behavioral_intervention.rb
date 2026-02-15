# frozen_string_literal: true

class BehavioralIntervention < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :behavioral_interventions
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
