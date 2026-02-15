# frozen_string_literal: true

# DM Scope Security Audit: shows current dmScope settings and warns about unsafe configs.
#
# OpenClaw's `session.dmScope` controls how DM isolation works:
# - "sender" (default, safe): each sender gets their own session
# - "main" (risky): all senders share the main session (messages visible across users)
class DmScopeAuditController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /security/dm_scope
  def show
    @config_data = gateway_client.config_get
    @health_data = gateway_client.health
    @channels_data = gateway_client.channels_status

    @dm_scope = extract_dm_scope(@config_data)
    @channels = extract_channels(@channels_data, @config_data)
    @warnings = compute_warnings(@dm_scope, @channels)
    @recommendations = compute_recommendations(@dm_scope, @channels)
  end

  private

  def extract_dm_scope(config)
    return { mode: "unknown", raw: nil } unless config.is_a?(Hash) && config["error"].blank?

    raw = config.dig("config") || config
    session = raw["session"] || {}

    {
      mode: session["dmScope"] || session["dm_scope"] || "sender",
      identity_links: session["identityLinks"] || [],
      compaction_mode: session["compactionMode"] || "auto",
      raw: session
    }
  end

  def extract_channels(channels_data, config)
    channels = []

    if channels_data.is_a?(Hash) && channels_data["error"].blank?
      Array(channels_data["channels"]).each do |c|
        channels << {
          name: c["name"] || c["type"],
          connected: c["connected"] || c["online"],
          multi_user: c["multiUser"] || false
        }
      end
    end

    # Also check config for configured channels
    if channels.empty? && config.is_a?(Hash)
      raw = config.dig("config") || config
      %w[telegram discord whatsapp signal slack irc matrix googlechat].each do |ch|
        if raw[ch].present?
          channels << { name: ch, connected: nil, multi_user: ch != "telegram" }
        end
      end
    end

    channels
  end

  def compute_warnings(dm_scope, channels)
    warnings = []

    if dm_scope[:mode] == "main"
      warnings << {
        level: "critical",
        title: "DM Scope set to 'main' — messages shared across all senders",
        description: "All DMs go to the same session. Sender A can see messages from Sender B. " \
                     "This is a privacy risk in multi-user setups."
      }

      if channels.size > 1
        warnings << {
          level: "critical",
          title: "Multiple channels with shared main session",
          description: "#{channels.size} channels configured with 'main' dmScope. " \
                       "Cross-channel message leakage is possible."
        }
      end
    end

    if dm_scope[:mode] == "sender" && dm_scope[:identity_links].empty? && channels.size > 1
      warnings << {
        level: "info",
        title: "No identity links configured with multiple channels",
        description: "The same user on different channels (e.g., Telegram + Discord) " \
                     "will be treated as separate people. Consider adding identity links."
      }
    end

    warnings
  end

  def compute_recommendations(dm_scope, channels)
    recs = []

    if dm_scope[:mode] == "main"
      recs << {
        action: "Switch dmScope to 'sender'",
        config_change: '{"session": {"dmScope": "sender"}}',
        risk: "low"
      }
    end

    if channels.size > 1 && dm_scope[:identity_links].empty?
      recs << {
        action: "Add identity links for cross-channel users",
        config_change: nil,
        risk: "none",
        link: "/identity_links"
      }
    end

    recs
  end
end
