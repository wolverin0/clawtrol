class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    # Status counts (single grouped query instead of 3 separate queries)
    status_counts = current_user.tasks.where.not(status: [:done, :archived]).group(:status).count
    @inbox_count = status_counts["inbox"] || 0
    @active_count = status_counts["in_progress"] || 0
    @review_count = status_counts["in_review"] || 0
    @error_count = current_user.tasks.where.not(error_message: nil).where.not(status: [:done, :archived]).count

    # Today's stats (single pluck instead of 3 separate queries)
    today_start = Time.zone.now.beginning_of_day
    today_tasks = current_user.tasks.where("created_at >= ? OR updated_at >= ? OR error_at >= ?", today_start, today_start, today_start)
      .pluck(:status, :created_at, :updated_at, :error_at)

    @done_today = today_tasks.count { |status, _, updated_at, _| status == "done" && updated_at && updated_at >= today_start }
    @spawned_today = today_tasks.count { |_, created_at, _, _| created_at && created_at >= today_start }
    @failed_today = today_tasks.count { |_, _, _, error_at| error_at && error_at >= today_start }

    # Active agents (in_progress tasks with models)
    @active_tasks = current_user.tasks
      .where(status: :in_progress)
      .includes(:board)
      .order(updated_at: :desc)
      .limit(10)

    # Recent tasks (not archived, across all boards)
    @recent_tasks = current_user.tasks
      .where.not(status: :archived)
      .includes(:board)
      .order(updated_at: :desc)
      .limit(10)

    # Model limits for status display
    @model_limits = ModelLimit.where(user: current_user).to_a

    # Board list for navigation reference
    @boards = current_user.boards.order(:name)

    # OpenClaw gateway cost data (best-effort, cached)
    @gateway_cost = begin
      client = OpenclawGatewayClient.new(current_user)
      Rails.cache.fetch("dashboard/cost/#{current_user.id}", expires_in: 60.seconds) do
        client.usage_cost
      end
    rescue => e
      nil
    end

    @gateway_health = begin
      client = OpenclawGatewayClient.new(current_user)
      Rails.cache.fetch("dashboard/health/#{current_user.id}", expires_in: 15.seconds) do
        client.health
      end
    rescue StandardError
      nil
    end
  end
end
