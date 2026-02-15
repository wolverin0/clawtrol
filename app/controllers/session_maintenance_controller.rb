# frozen_string_literal: true

class SessionMaintenanceController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /session-maintenance
  def show
    config_data = fetch_config
    @maintenance = extract_maintenance(config_data)
    @sessions_stats = fetch_session_stats
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /session-maintenance
  def update
    patch_and_redirect(
      build_maintenance_patch,
      redirect_path: session_maintenance_path,
      cache_key: "session_maint",
      reason: "Session maintenance config updated via ClawTrol",
      success_message: "Session maintenance config updated."
    )
  end

  private

  def fetch_config
    cached_config_get("session_maint")
  end

  def fetch_session_stats
    result = gateway_client.sessions_list rescue nil
    return {} unless result.is_a?(Hash) || result.is_a?(Array)

    sessions = result.is_a?(Array) ? result : (result["sessions"] || result[:sessions] || [])

    {
      total_count: sessions.size,
      active_count: sessions.count { |s| s["active"] == true || s[:active] == true },
      oldest: sessions.min_by { |s| s["createdAt"] || s[:created_at] || "9999" }&.dig("createdAt"),
      total_tokens: sessions.sum { |s| (s["totalTokens"] || s[:total_tokens] || 0).to_i }
    }
  rescue StandardError
    {}
  end

  def extract_maintenance(config)
    return default_maintenance if config.nil? || config["error"].present? || config[:error].present?

    store = config.dig("session", "store") || config.dig(:session, :store) || {}

    {
      prune_after_hours: store["pruneAfter"] || store["pruneAfterHours"] || 168,
      max_entries: store["maxEntries"] || 1000,
      rotate_bytes: store["rotateBytes"] || 0,
      auto_cleanup: store["autoCleanup"] != false
    }
  end

  def default_maintenance
    { prune_after_hours: 168, max_entries: 1000, rotate_bytes: 0, auto_cleanup: true }
  end

  def build_maintenance_patch
    mp = params.permit(:prune_after_hours, :max_entries, :rotate_bytes, :auto_cleanup)
    store_patch = {}

    if mp[:prune_after_hours].present?
      store_patch[:pruneAfter] = mp[:prune_after_hours].to_i.clamp(1, 8760) # 1h to 1 year
    end

    if mp[:max_entries].present?
      store_patch[:maxEntries] = mp[:max_entries].to_i.clamp(10, 100_000)
    end

    if mp[:rotate_bytes].present?
      store_patch[:rotateBytes] = mp[:rotate_bytes].to_i.clamp(0, 1_073_741_824) # up to 1GB
    end

    store_patch[:autoCleanup] = mp[:auto_cleanup] == "true" if mp.key?(:auto_cleanup)

    { session: { store: store_patch } }
  end
end
