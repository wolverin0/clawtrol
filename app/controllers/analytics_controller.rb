# frozen_string_literal: true

class AnalyticsController < ApplicationController
  before_action :require_authentication

  # Cost Analytics (OpenClaw sessions JSONL)
  def show
    @tab = %w[overview budget].include?(params[:tab]) ? params[:tab] : "overview"
    load_budget_data if @tab == "budget"
    @period = normalize_period(params[:period])

    data = Rails.cache.fetch(analytics_cache_key(@period), expires_in: cache_ttl) do
      SessionCostAnalytics.call(period: @period)
    end

    @generated_at = Time.parse(data[:generatedAt]) rescue Time.current
    @start_time = data[:rangeStart].present? ? (Time.parse(data[:rangeStart]) rescue nil) : nil
    @start_time ||= case @period
                    when "24h" then 24.hours.ago
                    when "7d"  then 7.days.ago
                    when "30d" then 30.days.ago
                    else            @generated_at - 1.year
                    end

    @total_cost        = data.dig(:stats, :totalCost) || 0.0
    @total_input       = data.dig(:tokens, :input) || 0
    @total_output      = data.dig(:tokens, :output) || 0
    @total_cache_read  = data.dig(:tokens, :cacheRead) || 0
    @total_cache_write = data.dig(:tokens, :cacheWrite) || 0
    @total_tokens      = data.dig(:stats, :totalTokens) || 0

    @cost_by_model = (data[:costByModel] || []).each_with_object({}) do |entry, h|
      h[entry[:model]] = entry[:cost]
    end
    @max_model_cost = @cost_by_model.values.max || 0.0

    @daily_cost = (data[:costOverTime] || []).each_with_object({}) do |entry, h|
      h[Date.parse(entry[:date])] = entry[:cost]
    end
    @max_daily_cost = @daily_cost.values.max || 0.0

    @top_sessions = (data[:topSessions] || []).map do |entry|
      { sessionId: entry[:session], cost: entry[:cost] }
    end

    # Projected monthly cost based on daily average
    @api_calls = data.dig(:stats, :apiCalls) || 0
    @cache_hit_rate = ((data.dig(:stats, :cacheHitRate) || 0) * 100).round(1)
    if @daily_cost.any? && @period.in?(%w[7d 30d])
      days = @daily_cost.size.to_f
      daily_avg = @total_cost / days
      @projected_monthly = (daily_avg * 30).round(4)
    end
  end

  # Budget & Trends tab data
  def budget
    @period = normalize_period(params[:period])
    load_budget_data

    respond_to do |format|
      format.html { render :budget }
      format.json { render json: @budget_data }
    end
  end

  # Update budget limit for a period
  def update_budget
    period = %w[daily weekly monthly].include?(params[:budget_period]) ? params[:budget_period] : "daily"
    limit = params[:budget_limit].to_f

    if limit <= 0
      redirect_to analytics_path(tab: "budget"), alert: "Budget must be positive"
      return
    end

    # Update or create today's snapshot with the new budget limit
    snapshot = CostSnapshot.find_or_initialize_by(
      user: Current.user,
      period: period,
      snapshot_date: Date.current
    )
    snapshot.budget_limit = limit
    snapshot.total_cost ||= 0
    snapshot.total_input_tokens ||= 0
    snapshot.total_output_tokens ||= 0
    snapshot.api_calls ||= 0

    if snapshot.save
      redirect_to analytics_path(tab: "budget"), notice: "#{period.capitalize} budget set to $#{format('%.2f', limit)}"
    else
      redirect_to analytics_path(tab: "budget"), alert: snapshot.errors.full_messages.join(", ")
    end
  end

  # Trigger manual snapshot capture
  def capture_snapshot
    CostSnapshotService.capture_daily(Current.user, date: Date.yesterday)
    redirect_to analytics_path(tab: "budget"), notice: "Daily snapshot captured for yesterday"
  rescue StandardError => e
    redirect_to analytics_path(tab: "budget"), alert: "Capture failed: #{e.message}"
  end

  private

  VALID_PERIODS = %w[24h 7d 30d all].freeze

  def normalize_period(value)
    VALID_PERIODS.include?(value) ? value : "7d"
  end

  def cache_ttl
    Integer(ENV.fetch("ANALYTICS_CACHE_TTL_SECONDS", "30")).seconds
  rescue ArgumentError
    30.seconds
  end

  def analytics_cache_key(period)
    "analytics/openclaw_cost/v2/period=#{period}"
  end

  def load_budget_data
    user = Current.user
    return unless user

    @daily_snapshots = CostSnapshot.for_user(user).daily.recent(30).order(:snapshot_date)
    @weekly_snapshots = CostSnapshot.for_user(user).weekly.recent(12).order(:snapshot_date)
    @monthly_snapshots = CostSnapshot.for_user(user).monthly.recent(12).order(:snapshot_date)

    @daily_summary = CostSnapshot.summary(user: user, period: "daily", days: 30)
    @weekly_summary = CostSnapshot.summary(user: user, period: "weekly", days: 90)
    @monthly_summary = CostSnapshot.summary(user: user, period: "monthly", days: 365)

    # Current budget from most recent snapshot
    @current_daily_budget = CostSnapshot.for_user(user).daily.where.not(budget_limit: nil).order(snapshot_date: :desc).first&.budget_limit
    @current_weekly_budget = CostSnapshot.for_user(user).weekly.where.not(budget_limit: nil).order(snapshot_date: :desc).first&.budget_limit
    @current_monthly_budget = CostSnapshot.for_user(user).monthly.where.not(budget_limit: nil).order(snapshot_date: :desc).first&.budget_limit

    # Budget alerts
    @budget_alerts = CostSnapshot.for_user(user).over_budget.recent(10).order(snapshot_date: :desc)

    # Cost by task (from TokenUsage, last 30 days)
    @cost_by_task = TokenUsage
      .for_user(user)
      .where("token_usages.created_at >= ?", 30.days.ago)
      .joins(:task)
      .group("tasks.id", "tasks.name")
      .select("tasks.id as task_id", "tasks.name as task_name", "SUM(token_usages.cost) as total_cost", "COUNT(*) as usage_count")
      .order("total_cost DESC")
      .limit(20)

    @budget_data = {
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
