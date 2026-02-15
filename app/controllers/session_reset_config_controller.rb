# frozen_string_literal: true

class SessionResetConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  RESET_MODES = %w[daily idle never].freeze
  RESET_TYPES = %w[direct group thread].freeze

  # GET /session-reset
  def show
    config_data = fetch_config
    @reset_config = extract_reset_config(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /session-reset
  def update
    patch = build_reset_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Session reset policy updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to session_reset_config_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("session_reset")
      redirect_to session_reset_config_path, notice: "Session reset policy updated."
    end
  rescue StandardError => e
    redirect_to session_reset_config_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("session_reset")
  end

  def extract_reset_config(config)
    return default_reset_config if config.nil? || config["error"].present? || config[:error].present?

    session = config.dig("session") || config.dig(:session) || {}
    reset = session.dig("reset") || session.dig(:reset) || {}

    {
      mode: reset["mode"] || "daily",
      at_hour: reset["atHour"] || 4,
      idle_minutes: reset["idleMinutes"] || 120,
      reset_by_channel: reset["resetByChannel"] != false,
      reset_by_type: Array(reset["resetByType"] || RESET_TYPES),
      reset_triggers: Array(reset["resetTriggers"] || []),
      per_channel: extract_per_channel_reset(session)
    }
  end

  def extract_per_channel_reset(session)
    channels = session.dig("channels") || {}
    result = {}
    channels.each do |ch, cfg|
      next unless cfg.is_a?(Hash) && cfg["reset"].is_a?(Hash)
      result[ch] = {
        mode: cfg.dig("reset", "mode"),
        at_hour: cfg.dig("reset", "atHour"),
        idle_minutes: cfg.dig("reset", "idleMinutes")
      }.compact
    end
    result
  end

  def default_reset_config
    {
      mode: "daily",
      at_hour: 4,
      idle_minutes: 120,
      reset_by_channel: true,
      reset_by_type: RESET_TYPES.dup,
      reset_triggers: [],
      per_channel: {}
    }
  end

  def build_reset_patch
    rp = params.permit(:mode, :at_hour, :idle_minutes, :reset_by_channel, reset_by_type: [], reset_triggers: [])
    reset_patch = {}

    if rp[:mode].present? && RESET_MODES.include?(rp[:mode])
      reset_patch[:mode] = rp[:mode]
    end

    if rp[:at_hour].present?
      reset_patch[:atHour] = rp[:at_hour].to_i.clamp(0, 23)
    end

    if rp[:idle_minutes].present?
      reset_patch[:idleMinutes] = rp[:idle_minutes].to_i.clamp(5, 1440)
    end

    if rp.key?(:reset_by_channel)
      reset_patch[:resetByChannel] = rp[:reset_by_channel] == "true" || rp[:reset_by_channel] == "1"
    end

    if rp[:reset_by_type].present?
      reset_patch[:resetByType] = rp[:reset_by_type].select { |t| RESET_TYPES.include?(t) }
    end

    { session: { reset: reset_patch } }
  end
end
