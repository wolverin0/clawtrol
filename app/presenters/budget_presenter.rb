# frozen_string_literal: true

# Presenter for budget analytics data transformation.
# Extracts view model logic from AnalyticsController#budget.
class BudgetPresenter
  def initialize(user:, period: "7d")
    @user = user
    @period = period
  end

  attr_reader :daily_snapshots, :weekly_snapshots, :monthly_snapshots,
              :current_daily_budget, :current_weekly_budget, :current_monthly_budget,
              :budget_alerts, :cost_by_task, :budget_data

  def render
    load_budget_data
    @budget_data = build_budget_data
    self
  end

  private

  def load_budget_data
    @daily_snapshots = CostSnapshot.for_user(@user).daily.recent(30).order(:snapshot_date)
    @weekly_snapshots = CostSnapshot.for_user(@user).weekly.recent(12).order(:snapshot_date)
    @monthly_snapshots = CostSnapshot.for_user(@user).monthly.recent(12).order(:snapshot_date)

    @daily_summary = CostSnapshot.summary(user: @user, period: "daily", days: 30)
    @weekly_summary = CostSnapshot.summary(user: @user, period: "weekly", days: 90)
    @monthly_summary = CostSnapshot.summary(user: @user, period: "monthly", days: 365)

    @current_daily_budget = CostSnapshot.for_user(@user).daily.where.not(budget_limit: nil).order(snapshot_date: :desc).first&.budget_limit
    @current_weekly_budget = CostSnapshot.for_user(@user).weekly.where.not(budget_limit: nil).order(snapshot_date: :desc).first&.budget_limit
    @current_monthly_budget = CostSnapshot.for_user(@user).monthly.where.not(budget_limit: nil).order(snapshot_date: :desc).first&.budget_limit

    @budget_alerts = CostSnapshot.for_user(@user).over_budget.recent(10).order(snapshot_date: :desc)

    @cost_by_task = TokenUsage
      .for_user(@user)
      .where("token_usages.created_at >= ?", 30.days.ago)
      .joins(:task)
      .group("tasks.id", "tasks.name")
      .select("tasks.id as task_id", "tasks.name as task_name", "SUM(token_usages.cost) as total_cost", "COUNT(*) as usage_count")
      .order("total_cost DESC")
      .limit(20)
  end

  def build_budget_data
    {
      daily: format_summary(@daily_summary, @current_daily_budget),
      weekly: format_summary(@weekly_summary, @current_weekly_budget),
      monthly: format_summary(@monthly_summary, @current_monthly_budget),
      alerts_count: @budget_alerts.count
    }
  end

  def format_summary(summary, budget)
    return { empty: true } if summary.blank?
    summary.merge(budget: budget)
  end
end
