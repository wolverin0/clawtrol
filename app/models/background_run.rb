# frozen_string_literal: true

class BackgroundRun < ApplicationRecord
  strict_loading :n_plus_one

  belongs_to :user
  belongs_to :task, optional: true
  belongs_to :openclaw_flow, optional: true

  validates :run_id, presence: true, uniqueness: true
  validates :run_type, presence: true, inclusion: { in: %w[cron subagent acp manual] }
  validates :status, inclusion: { in: %w[running completed failed cancelled timeout] }

  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(started_at: :desc) }
  scope :by_type, ->(type) { where(run_type: type) }
  scope :for_user, ->(user) { where(user: user) }
  scope :today, -> { where("started_at >= ?", Time.current.beginning_of_day) }

  def running? = status == "running"
  def completed? = status == "completed"
  def failed? = status == "failed"

  def duration_human
    return nil unless duration_seconds

    if duration_seconds < 60
      "#{duration_seconds}s"
    elsif duration_seconds < 3600
      "#{(duration_seconds / 60.0).round(1)}m"
    else
      "#{(duration_seconds / 3600.0).round(1)}h"
    end
  end

  def total_tokens
    (tokens_in || 0) + (tokens_out || 0)
  end
end
