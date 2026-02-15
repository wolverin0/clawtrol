class AuditReport < ApplicationRecord
  belongs_to :user
  has_many :behavioral_interventions

  validates :report_type, inclusion: { in: %w[daily weekly] }
  validates :overall_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }

  scope :daily, -> { where(report_type: "daily") }
  scope :weekly, -> { where(report_type: "weekly") }
  scope :recent, -> { order(created_at: :desc) }
end
