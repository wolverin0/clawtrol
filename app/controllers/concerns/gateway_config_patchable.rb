# frozen_string_literal: true

# Shared behavior for controllers that patch OpenClaw gateway config.
#
# Provides:
# - `apply_config_patch(key, data, reason:)` — wraps gateway_client.config_patch
#   with consistent error handling and JSON response.
# - `render_config_success(message)` / `render_config_error(error, status:)` —
#   standardized JSON responses.
# - `validate_section!(section, allowed:)` — validates section param.
#
# Usage:
#   class SomeConfigController < ApplicationController
#     include GatewayClientAccessible
#     include GatewayConfigPatchable
#
#     def update
#       validate_section!(params[:section], allowed: %w[logging debug]) or return
#       # ... build patch_data ...
#       apply_config_patch("logging", patch_data, reason: "Logging updated")
#     end
#   end
module GatewayConfigPatchable
  extend ActiveSupport::Concern

  private

  # Apply a config patch to the gateway via config_patch RPC.
  #
  # @param key [String] top-level config key (e.g., "channels", "skills")
  # @param data [Hash] the data to merge under that key
  # @param reason [String] human-readable reason for the change
  # @return [void] renders JSON response
  def apply_config_patch(key, data, reason: "Config updated from ClawTrol")
    patch  = { key => data }
    result = gateway_client.config_patch(
      raw:    patch.to_json,
      reason: reason
    )

    if result["error"].present?
      render_config_error(result["error"])
    else
      render_config_success("#{key.to_s.humanize} config saved. Gateway restarting…")
    end
  end

  # Apply a multi-key config patch.
  #
  # @param patch_hash [Hash] full patch hash (may have multiple keys)
  # @param reason [String] human-readable reason
  def apply_multi_config_patch(patch_hash, reason: "Config updated from ClawTrol")
    result = gateway_client.config_patch(
      raw:    patch_hash.to_json,
      reason: reason
    )

    if result["error"].present?
      render_config_error(result["error"])
    else
      render_config_success("Config saved. Gateway restarting…")
    end
  end

  # Validate that params[:section] is in the allowed list.
  # Renders an error and returns false if invalid.
  #
  # @param section [String]
  # @param allowed [Array<String>]
  # @return [Boolean] true if valid
  def validate_section!(section, allowed:)
    unless allowed.include?(section.to_s.strip)
      render json: { success: false, error: "Unknown section: #{section}" }, status: :unprocessable_entity
      return false
    end
    true
  end

  def render_config_success(message)
    render json: { success: true, message: message }
  end

  def render_config_error(error, status: :unprocessable_entity)
    render json: { success: false, error: error }, status: status
  end

  # Helper to extract and deep_dup the current config for a key.
  #
  # @param key [String] config key
  # @return [Hash] current config value (deep duped)
  def current_config_section(key)
    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    (raw_conf[key] || {}).deep_dup
  end

  # Helper to extract the full raw config.
  #
  # @return [Hash] the raw config hash
  def current_raw_config
    config = gateway_client.config_get
    config.is_a?(Hash) ? (config["config"] || config) : {}
  end

  # Apply a config patch and redirect back.
  # DRYs the common pattern across config controllers that use redirect (not JSON).
  #
  # @param patch [Hash] the config patch to apply
  # @param redirect_path [String] path to redirect to
  # @param cache_key [String, nil] optional cache key to invalidate on success
  # @param reason [String] human-readable reason for the change
  # @param success_message [String] flash notice on success
  def patch_and_redirect(patch, redirect_path:, cache_key: nil, reason: "Config updated via ClawTrol", success_message: "Configuration updated.")
    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: reason
    )

    if result["error"].present?
      redirect_to redirect_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache(cache_key) if cache_key.present?
      redirect_to redirect_path, notice: success_message
    end
  rescue StandardError => e
    redirect_to redirect_path, alert: "Error: #{e.message}"
  end

  # cached_config_get and invalidate_config_cache are now provided by
  # GatewayClientAccessible (available to all gateway-connected controllers).
end
