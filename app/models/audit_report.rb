# frozen_string_literal: true

class AuditReport < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user
  has_many :behavioral_interventions, dependent: :destroy, inverse_of: :audit_report

  validates :report_type, inclusion: { in: %w[daily weekly] }
  validates :overall_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :messages_analyzed, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :session_files_analyzed, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :report_type, presence: true
  validates :report_path, length: { maximum: 500 }, allow_nil: true

  validate :scores_must_be_hash, if: -> { scores.present? }
  validate :anti_pattern_counts_must_be_hash, if: -> { anti_pattern_counts.present? }

  scope :daily, -> { where(report_type: "daily") }
  scope :weekly, -> { where(report_type: "weekly") }
  scope :recent, -> { order(created_at: :desc) }

  private

  def scores_must_be_hash
    errors.add(:scores, "must be a JSON object") unless scores.is_a?(Hash)
  end

  def anti_pattern_counts_must_be_hash
    errors.add(:anti_pattern_counts, "must be a JSON object") unless anti_pattern_counts.is_a?(Hash)
  end
end
