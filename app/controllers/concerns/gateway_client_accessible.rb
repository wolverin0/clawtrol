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

  # Cached config fetch with user-scoped key and error handling.
  # Replaces the repeated `fetch_config` pattern across 15+ controllers.
  # Error responses are NOT cached to prevent transient failures from
  # being served stale for the full TTL.
  #
  # @param cache_key [String] short key name (e.g., "typing_cfg", "identity_cfg")
  # @param expires_in [ActiveSupport::Duration] cache TTL (default: 30 seconds)
  # @return [Hash] the config hash, or { "error" => message } on failure
  def cached_config_get(cache_key, expires_in: 30.seconds)
    full_key = "#{cache_key}/#{current_user.id}"
    cached = Rails.cache.read(full_key)
    return cached if cached && !(cached.is_a?(Hash) && cached["error"].present?)

    result = gateway_client.config_get
    Rails.cache.write(full_key, result, expires_in: expires_in) unless result.is_a?(Hash) && result["error"].present?
    result
  rescue StandardError => e
    { "error" => e.message }
  end

  # Invalidate a cached config key for the current user.
  #
  # @param cache_key [String] the same key used in cached_config_get
  def invalidate_config_cache(cache_key)
    Rails.cache.delete("#{cache_key}/#{current_user.id}")
  end
end
