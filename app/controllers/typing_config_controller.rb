# frozen_string_literal: true

class TypingConfigController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  TYPING_MODES = %w[never instant thinking message].freeze

  # GET /typing-config
  def show
    config_data = fetch_config
    @typing = extract_typing_config(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /typing-config
  def update
    patch = build_typing_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Typing indicator config updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to typing_config_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("typing_cfg")
      redirect_to typing_config_path, notice: "Typing indicator config updated."
    end
  rescue StandardError => e
    redirect_to typing_config_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("typing_cfg")
  end

  def extract_typing_config(config)
    return default_typing if config.nil? || config["error"].present? || config[:error].present?

    typing = config.dig("typing") || config.dig(:typing) || {}

    {
      mode: typing["mode"] || "thinking",
      interval_ms: typing["intervalMs"] || typing["interval"] || 5000,
      per_channel: extract_per_channel(config)
    }
  end

  def extract_per_channel(config)
    channels = config.dig("channels") || {}
    result = {}
    channels.each do |ch, cfg|
      next unless cfg.is_a?(Hash) && cfg["typing"].is_a?(Hash)
      result[ch] = { mode: cfg.dig("typing", "mode"), interval_ms: cfg.dig("typing", "intervalMs") }.compact
    end
    result
  end

  def default_typing
    { mode: "thinking", interval_ms: 5000, per_channel: {} }
  end

  def build_typing_patch
    tp = params.permit(:mode, :interval_ms)
    typing_patch = {}

    if tp[:mode].present? && TYPING_MODES.include?(tp[:mode])
      typing_patch[:mode] = tp[:mode]
    end

    if tp[:interval_ms].present?
      typing_patch[:intervalMs] = tp[:interval_ms].to_i.clamp(1000, 30_000)
    end

    { typing: typing_patch }
  end
end
