class AnalyticsController < ApplicationController
  before_action :require_authentication

  def show
    @period = params[:period] || "7d"
    days = case @period
           when "24h" then 1
           when "7d" then 7
           when "30d" then 30
           when "all" then 365
           else 7
           end

    @start_date = days.days.ago
    @tasks = current_user.tasks.where("created_at >= ?", @start_date)

    # Tasks by status
    @status_counts = @tasks.group(:status).count

    # Tasks completed per day (using DATE function for PostgreSQL)
    @daily_completions = current_user.tasks
      .where(status: [ :done, :archived ])
      .where("updated_at >= ?", @start_date)
      .group("DATE(updated_at)")
      .count
      .transform_keys { |k| k.to_date }
      .sort_by { |date, _| date }
      .to_h

    # Fill in missing dates with zeros for better visualization
    if @daily_completions.any?
      date_range = (@start_date.to_date..Date.current)
      @daily_completions = date_range.each_with_object({}) do |date, hash|
        hash[date] = @daily_completions[date] || 0
      end
    end

    # Model usage
    @model_usage = @tasks.where.not(model: [ nil, "" ]).group(:model).count

    # Average completion time (created → done) in hours
    avg_seconds = current_user.tasks
      .where(status: [ :done, :archived ])
      .where("updated_at >= ?", @start_date)
      .average("EXTRACT(EPOCH FROM (updated_at - created_at))")

    @avg_completion_hours = avg_seconds ? (avg_seconds / 3600.0).round(1) : 0

    # Board breakdown
    @board_stats = current_user.boards
      .left_joins(:tasks)
      .where("tasks.created_at >= ? OR tasks.id IS NULL", @start_date)
      .group("boards.id", "boards.name", "boards.icon")
      .select("boards.id, boards.name, boards.icon, COUNT(tasks.id) as task_count")
      .order("task_count DESC")

    # Total stats for the period
    @total_tasks = @tasks.count
    @completed_tasks = @tasks.where(status: [ :done, :archived ]).count
    @in_progress_tasks = @tasks.where(status: :in_progress).count
    @error_tasks = @tasks.where.not(error_message: nil).count

    # Completion rate
    @completion_rate = @total_tasks > 0 ? ((@completed_tasks.to_f / @total_tasks) * 100).round(1) : 0

    # Max daily for scaling bars
    @max_daily = @daily_completions.values.max || 1
    @max_model_usage = @model_usage.values.max || 1

    # === Token Usage Analytics (Foxhound) ===
    @token_usages = TokenUsage.for_user(current_user).by_date_range(@start_date)

    # Summary stats
    @total_input_tokens = @token_usages.total_input
    @total_output_tokens = @token_usages.total_output
    @total_tokens = @total_input_tokens + @total_output_tokens
    @total_cost = @token_usages.total_cost

    # Cost by model (for pie-like display)
    @cost_by_model = @token_usages.cost_by_model
    @max_model_cost = @cost_by_model.values.max || 0

    # Tokens by model (detailed)
    @tokens_by_model = @token_usages.tokens_by_model.to_a

    # Daily token usage (for line-like chart)
    daily_raw = @token_usages.daily_usage(@start_date)
    @daily_token_usage = {}
    daily_raw.each do |row|
      @daily_token_usage[row.date.to_date] = {
        input: row.total_input.to_i,
        output: row.total_output.to_i,
        cost: row.total_cost.to_f
      }
    end

    # Fill missing dates
    if @start_date.present?
      (@start_date.to_date..Date.current).each do |date|
        @daily_token_usage[date] ||= { input: 0, output: 0, cost: 0 }
      end
      @daily_token_usage = @daily_token_usage.sort.to_h
    end

    @max_daily_tokens = @daily_token_usage.values.map { |v| v[:input] + v[:output] }.max || 1

    # Per-board token breakdown
    @board_token_stats = @token_usages.by_board_breakdown.to_a

    # Today's stats (quick glance)
    today_usages = TokenUsage.for_user(current_user).by_date_range(Time.current.beginning_of_day)
    @today_tokens = today_usages.total_tokens_count
    @today_cost = today_usages.total_cost

    # This week
    week_usages = TokenUsage.for_user(current_user).by_date_range(Time.current.beginning_of_week)
    @week_tokens = week_usages.total_tokens_count
    @week_cost = week_usages.total_cost

    # This month
    month_usages = TokenUsage.for_user(current_user).by_date_range(Time.current.beginning_of_month)
    @month_tokens = month_usages.total_tokens_count
    @month_cost = month_usages.total_cost
  end
end
