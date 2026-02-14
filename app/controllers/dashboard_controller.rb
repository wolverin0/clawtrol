class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    # Status counts (across all boards)
    @inbox_count = current_user.tasks.where(status: :inbox).count
    @active_count = current_user.tasks.where(status: :in_progress).count
    @review_count = current_user.tasks.where(status: :in_review).count
    @error_count = current_user.tasks.where.not(error_message: nil).where.not(status: [:done, :archived]).count

    # Today's stats
    today_start = Time.zone.now.beginning_of_day
    @done_today = current_user.tasks.where(status: :done).where("updated_at >= ?", today_start).count
    @spawned_today = current_user.tasks.where("created_at >= ?", today_start).count
    @failed_today = current_user.tasks.where.not(error_at: nil).where("error_at >= ?", today_start).count

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
    rescue => e
      nil
    end
  end
end
