# frozen_string_literal: true

class DashboardController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication

  def show
    data = DashboardDataService.call(user: current_user, gateway_client: gateway_client)

    @inbox_count          = data.inbox_count
    @active_count         = data.active_count
    @review_count         = data.review_count
    @error_count          = data.error_count
    @done_today           = data.done_today
    @spawned_today        = data.spawned_today
    @failed_today         = data.failed_today
    @active_tasks         = data.active_tasks
    @recent_tasks         = data.recent_tasks
    @model_limits         = data.model_limits
    @boards               = data.boards
    @gateway_cost         = data.gateway_cost
    @cost_analytics       = data.cost_analytics
    @gateway_health       = data.gateway_health
    @saved_links_pending  = data.saved_links_pending
    @saved_links_recent   = data.saved_links_recent
    @feed_unread_count    = data.feed_unread_count
    @feed_high_relevance_count = data.feed_high_relevance_count
    @feed_recent          = data.feed_recent
  end
end
