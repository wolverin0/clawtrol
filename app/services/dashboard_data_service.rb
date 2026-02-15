# frozen_string_literal: true

# Assembles all data needed for the main dashboard view.
# Keeps DashboardController#show thin and testable.
class DashboardDataService
  Result = Struct.new(
    :inbox_count, :active_count, :review_count, :error_count,
    :done_today, :spawned_today, :failed_today,
    :active_tasks, :recent_tasks, :model_limits, :boards,
    :gateway_cost, :cost_analytics, :gateway_health,
    :saved_links_pending, :saved_links_recent,
    :feed_unread_count, :feed_high_relevance_count, :feed_recent,
    keyword_init: true
  )

  def initialize(user:, gateway_client:)
    @user = user
    @gateway_client = gateway_client
  end

  def call
    Result.new(
      **status_counts,
      **today_stats,
      active_tasks: active_tasks,
      recent_tasks: recent_tasks,
      model_limits: ModelLimit.where(user: @user).to_a,
      boards: @user.boards.order(:name),
      gateway_cost: cached_gateway_cost,
      cost_analytics: cached_cost_analytics,
      gateway_health: cached_gateway_health,
      saved_links_pending: @user.saved_links.unprocessed.count,
      saved_links_recent: @user.saved_links.newest_first.limit(5),
      feed_unread_count: @user.feed_entries.unread.count,
      feed_high_relevance_count: @user.feed_entries.high_relevance.unread.count,
      feed_recent: @user.feed_entries.newest_first.limit(5)
    )
  end

  def self.call(user:, gateway_client:)
    new(user: user, gateway_client: gateway_client).call
  end

  private

  def status_counts
    counts = @user.tasks.where.not(status: [:done, :archived]).group(:status).count
    {
      inbox_count: counts["inbox"] || 0,
      active_count: counts["in_progress"] || 0,
      review_count: counts["in_review"] || 0,
      error_count: @user.tasks.where.not(error_message: nil).where.not(status: [:done, :archived]).count
    }
  end

  def today_stats
    today_start = Time.zone.now.beginning_of_day
    rows = @user.tasks
      .where("created_at >= ? OR updated_at >= ? OR error_at >= ?", today_start, today_start, today_start)
      .pluck(:status, :created_at, :updated_at, :error_at)

    done_int = Task.statuses["done"]
    {
      done_today: rows.count { |s, _, u, _| s == done_int && u && u >= today_start },
      spawned_today: rows.count { |_, c, _, _| c && c >= today_start },
      failed_today: rows.count { |_, _, _, e| e && e >= today_start }
    }
  end

  def active_tasks
    @user.tasks
      .where(status: :in_progress)
      .includes(:board)
      .order(updated_at: :desc)
      .limit(10)
  end

  def recent_tasks
    @user.tasks
      .where.not(status: :archived)
      .includes(:board)
      .order(updated_at: :desc)
      .limit(10)
  end

  def cached_gateway_cost
    Rails.cache.fetch("dashboard/cost/#{@user.id}", expires_in: 60.seconds) do
      @gateway_client.usage_cost
    end
  rescue StandardError
    nil
  end

  def cached_cost_analytics
    Rails.cache.fetch("dashboard/cost_analytics/#{@user.id}", expires_in: 120.seconds) do
      SessionCostAnalytics.call(period: "7d")
    end
  rescue StandardError
    nil
  end

  def cached_gateway_health
    Rails.cache.fetch("dashboard/health/#{@user.id}", expires_in: 15.seconds) do
      @gateway_client.health
    end
  rescue StandardError
    nil
  end
end
