# frozen_string_literal: true

# Provides a memoized OpenClaw gateway client instance.
# Include in controllers that need to interact with the OpenClaw Gateway API.
#
# Usage:
#   class SomeController < ApplicationController
#     include GatewayClientAccessible
#
#     def index
#       data = gateway_client.health
#     end
#   end
module GatewayClientAccessible
  extend ActiveSupport::Concern

  private

  # Memoized gateway client for the current user.
  # @return [OpenclawGatewayClient]
  def gateway_client
    @_gateway_client ||= OpenclawGatewayClient.new(current_user)
  end

  # Check if the current user has gateway configured.
  # @return [Boolean]
  def gateway_configured?
    current_user&.openclaw_gateway_url.present?
  end

  # Before action helper: redirects to settings if gateway is not configured.
  def ensure_gateway_configured!
    return if gateway_configured?

    respond_to do |format|
      format.html { redirect_to settings_path, alert: "Configure OpenClaw Gateway URL in Settings first" }
      format.json { render json: { error: "Gateway not configured" }, status: :service_unavailable }
    end
  end
end
