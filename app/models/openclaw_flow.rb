# frozen_string_literal: true

class OpenclawFlow < ApplicationRecord
  strict_loading :n_plus_one

  belongs_to :user
  belongs_to :task, optional: true
  has_many :tasks, dependent: :nullify
  has_many :background_runs, dependent: :nullify

  validates :flow_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active blocked completed cancelled error] }

  scope :active, -> { where(status: "active") }
  scope :blocked, -> { where(status: "blocked") }
  scope :recent, -> { order(updated_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  def active?; status == "active"; end
  def blocked?; status == "blocked"; end
  def completed?; status == "completed"; end

  def progress_percent
    return 0 if child_count.zero?
    ((completed_count.to_f / child_count) * 100).round
  end
end
