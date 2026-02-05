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
  end
end
