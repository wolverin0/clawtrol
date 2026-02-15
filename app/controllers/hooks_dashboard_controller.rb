# frozen_string_literal: true

class HooksDashboardController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /hooks-dashboard
  def show
    config_data = fetch_config
    @hooks = extract_hooks(config_data)
    @gmail_config = extract_gmail_config(config_data)
    @recent_hits = WebhookLog.order(created_at: :desc).limit(25)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  private

  def fetch_config
    cached_config_get("hooks_dashboard")
  end

  def extract_hooks(config)
    return [] if config.nil? || config["error"].present? || config[:error].present?

    hooks_cfg = config.dig("hooks") || config.dig(:hooks) || {}
    mappings = hooks_cfg["mappings"] || hooks_cfg[:mappings] || []

    return [] unless mappings.is_a?(Array)

    mappings.map.with_index do |m, idx|
      {
        index: idx,
        match: m["match"] || m[:match] || {},
        action: m["action"] || m[:action] || {},
        template: m["template"] || m[:template],
        delivery: m["delivery"] || m[:delivery] || {},
        transform: m["transform"] || m[:transform],
        description: m["description"] || m[:description] || "Mapping ##{idx + 1}",
        source: detect_source(m)
      }
    end
  end

  def extract_gmail_config(config)
    return nil if config.nil? || config["error"].present? || config[:error].present?

    gmail = config.dig("hooks", "gmail") || config.dig(:hooks, :gmail) || {}
    return nil if gmail.empty?

    {
      enabled: gmail["enabled"] != false,
      label_watch: gmail["labelWatch"] || gmail["labels"] || [],
      auto_renew: gmail["autoRenew"] != false,
      last_history_id: gmail["lastHistoryId"],
      watch_expiry: gmail["watchExpiry"],
      topic: gmail["pubsubTopic"] || gmail["topic"]
    }
  end

  def detect_source(mapping)
    match = mapping["match"] || mapping[:match] || {}
    headers = match["headers"] || {}

    if headers["X-GitHub-Event"].present? || match["source"]&.match?(/github/i)
      "GitHub"
    elsif headers["X-N8N-Event"].present? || match["source"]&.match?(/n8n/i)
      "n8n"
    elsif match["source"]&.match?(/gmail|google/i)
      "Gmail"
    else
      "Custom"
    end
  end
end
