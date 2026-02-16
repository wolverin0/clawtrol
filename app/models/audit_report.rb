# frozen_string_literal: true

class AuditReport < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :audit_reports
  has_many :behavioral_interventions, dependent: :destroy, inverse_of: :audit_report

  validates :report_type, inclusion: { in: %w[daily weekly] }
  validates :overall_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }

  scope :daily, -> { where(report_type: "daily") }
  scope :weekly, -> { where(report_type: "weekly") }
  scope :recent, -> { order(created_at: :desc) }
end
