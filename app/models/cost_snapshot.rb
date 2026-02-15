# frozen_string_literal: true

# Periodic cost snapshots for budget tracking and trend analysis.
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

# Captured daily/weekly/monthly by CostSnapshotService.
class CostSnapshot < ApplicationRecord
  belongs_to :user, inverse_of: :user

  PERIODS = %w[daily weekly monthly].freeze

  validates :period, presence: true, inclusion: { in: PERIODS }
  validates :snapshot_date, presence: true
  validates :total_cost, numericality: { greater_than_or_equal_to: 0 }
  validates :total_input_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_output_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :api_calls, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :budget_limit, numericality: { greater_than: 0 }, allow_nil: true

  validate :snapshot_date_uniqueness_per_user_period

  scope :for_user, ->(user) { where(user: user) }
  scope :daily, -> { where(period: "daily") }
  scope :weekly, -> { where(period: "weekly") }
  scope :monthly, -> { where(period: "monthly") }
  scope :recent, ->(n = 30) { order(snapshot_date: :desc).limit(n) }
  scope :between, ->(start_date, end_date) { where(snapshot_date: start_date..end_date) }
  scope :over_budget, -> { where(budget_exceeded: true) }

  before_save :check_budget_exceeded

  # Total tokens for this snapshot
  def total_tokens
    total_input_tokens + total_output_tokens
  end

  # Budget utilization percentage (nil if no budget set)
  def budget_utilization
    return nil unless budget_limit&.positive?
    (total_cost / budget_limit * 100).round(1)
  end

  # Top spending model from the snapshot
  def top_model
    return nil if cost_by_model.blank?
    cost_by_model.max_by { |_, v| v.to_f }&.first
  end

  # Projected monthly cost based on this snapshot's daily rate
  def projected_monthly_cost
    return total_cost if period == "monthly"

    daily_rate = case period
                 when "daily" then total_cost
                 when "weekly" then total_cost / 7.0
                 else total_cost
                 end

    (daily_rate * 30).round(6)
  end

  class << self
    # Get the trend direction: :up, :down, :flat
    def trend(user:, period: "daily", lookback: 7)
      snapshots = for_user(user)
        .where(period: period)
        .order(snapshot_date: :desc)
        .limit(lookback)
        .pluck(:total_cost)

      return :flat if snapshots.size < 2

      recent_avg = snapshots.first(lookback / 2).sum / (lookback / 2).to_f
      older_avg = snapshots.last(lookback / 2).sum / (lookback / 2).to_f

      return :flat if older_avg.zero?

      change = (recent_avg - older_avg) / older_avg
      if change > 0.1
        :up
      elsif change < -0.1
        :down
      else
        :flat
      end
    end

    # Summary stats for a given user and period range
    def summary(user:, period: "daily", days: 30)
      snaps = for_user(user)
        .where(period: period)
        .where("snapshot_date >= ?", days.days.ago.to_date)
        .order(:snapshot_date)

      costs = snaps.pluck(:total_cost)
      return {} if costs.empty?

      {
        total: costs.sum.round(6),
        average: (costs.sum / costs.size).round(6),
        min: costs.min.round(6),
        max: costs.max.round(6),
        count: costs.size,
        trend: trend(user: user, period: period)
      }
    end
  end

  private

  def check_budget_exceeded
    self.budget_exceeded = budget_limit.present? && total_cost > budget_limit
  end

  def snapshot_date_uniqueness_per_user_period
    return unless snapshot_date && user_id && period

    existing = CostSnapshot.where(user_id: user_id, period: period, snapshot_date: snapshot_date)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:snapshot_date, "already has a #{period} snapshot for this user")
    end
  end
end
