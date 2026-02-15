# frozen_string_literal: true

class HeartbeatConfigController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /heartbeat-config
  def show
    config_data = fetch_config
    @heartbeat_config = extract_heartbeat_config(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /heartbeat-config
  def update
    patch = build_heartbeat_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Heartbeat config updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to heartbeat_config_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("heartbeat_config")
      redirect_to heartbeat_config_path, notice: "Heartbeat configuration updated."
    end
  rescue StandardError => e
    redirect_to heartbeat_config_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("heartbeat_config")
  end

  def extract_heartbeat_config(config)
    return default_heartbeat_config if config.nil? || config["error"].present? || config[:error].present?

    hb = config.dig("heartbeat") || config.dig(:heartbeat) || {}

    {
      enabled: hb["enabled"] != false,
      interval_minutes: hb["intervalMinutes"] || hb["interval"] || 60,
      model: hb["model"] || "",
      target_channel: hb["targetChannel"] || hb["channel"] || "",
      prompt: hb["prompt"] || "",
      ack_max_chars: hb["ackMaxChars"] || 500,
      include_reasoning: hb["includeReasoning"] == true,
      quiet_hours_start: hb.dig("quietHours", "start") || 23,
      quiet_hours_end: hb.dig("quietHours", "end") || 8
    }
  end

  def default_heartbeat_config
    {
      enabled: true,
      interval_minutes: 60,
      model: "",
      target_channel: "",
      prompt: "",
      ack_max_chars: 500,
      include_reasoning: false,
      quiet_hours_start: 23,
      quiet_hours_end: 8
    }
  end

  def build_heartbeat_patch
    hp = params.permit(:enabled, :interval_minutes, :model, :target_channel,
                       :prompt, :ack_max_chars, :include_reasoning,
                       :quiet_hours_start, :quiet_hours_end)

    hb_patch = {}
    hb_patch[:enabled] = hp[:enabled] == "true" || hp[:enabled] == "1" if hp.key?(:enabled)

    if hp[:interval_minutes].present?
      hb_patch[:intervalMinutes] = hp[:interval_minutes].to_i.clamp(5, 1440)
    end

    hb_patch[:model] = hp[:model] if hp[:model].present?
    hb_patch[:targetChannel] = hp[:target_channel] if hp[:target_channel].present?
    hb_patch[:prompt] = hp[:prompt] if hp[:prompt].present?

    if hp[:ack_max_chars].present?
      hb_patch[:ackMaxChars] = hp[:ack_max_chars].to_i.clamp(50, 5000)
    end

    hb_patch[:includeReasoning] = hp[:include_reasoning] == "true" if hp.key?(:include_reasoning)

    if hp[:quiet_hours_start].present? || hp[:quiet_hours_end].present?
      hb_patch[:quietHours] = {
        start: (hp[:quiet_hours_start] || 23).to_i.clamp(0, 23),
        end: (hp[:quiet_hours_end] || 8).to_i.clamp(0, 23)
      }
    end

    { heartbeat: hb_patch }
  end
end
