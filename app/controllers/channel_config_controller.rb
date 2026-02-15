# frozen_string_literal: true

# Unified config pages for non-Telegram/Discord channels:
# Mattermost, Slack, and Signal.
#
# Each channel has its own unique options:
# - Mattermost: chatmode (oncall/onmessage/onchar), server URL
# - Slack: socket vs HTTP mode, slash commands, thread config
# - Signal: reaction modes, group handling
class ChannelConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!
  before_action :validate_channel!

  SUPPORTED_CHANNELS = %w[mattermost slack signal].freeze

  # GET /channel_config/:channel
  def show
    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}

    @channel_name   = params[:channel].to_s.downcase
    @channels       = raw_conf.dig("channels") || {}
    @channel_data   = extract_channel(@channels, @channel_name)
    @channel_status = gateway_client.channels_status
  end

  # POST /channel_config/:channel/update
  def update
    channel_name = params[:channel].to_s.downcase
    values       = params[:values]

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    channels = (raw_conf["channels"] || {}).deep_dup

    ch_key = find_channel_key(channels, channel_name)
    channels[ch_key] ||= {}

    case channel_name
    when "mattermost"
      apply_mattermost(channels[ch_key], values)
    when "slack"
      apply_slack(channels[ch_key], values)
    when "signal"
      apply_signal(channels[ch_key], values)
    end

    patch  = { "channels" => channels }
    result = gateway_client.config_patch(
      raw:    patch.to_json,
      reason: "#{channel_name.capitalize} config updated from ClawTrol"
    )

    if result["error"].present?
      render json: { success: false, error: result["error"] }, status: :unprocessable_entity
    else
      render json: { success: true, message: "#{channel_name.capitalize} config saved. Gateway restarting…" }
    end
  end

  private

  def validate_channel!
    unless SUPPORTED_CHANNELS.include?(params[:channel].to_s.downcase)
      redirect_to root_path, alert: "Unknown channel: #{params[:channel]}"
    end
  end

  def find_channel_key(channels, name)
    channels.keys.find { |k| k.to_s.downcase.include?(name) } || name
  end

  def extract_channel(channels, name)
    ch_key = find_channel_key(channels, name)
    ch     = channels[ch_key] || {}

    base = {
      key:        ch_key,
      dm_scope:   ch.dig("dmScope") || "user",
      allowFrom:  ch.dig("allowFrom") || [],
      raw:        ch
    }

    case name
    when "mattermost"
      base.merge(extract_mattermost(ch))
    when "slack"
      base.merge(extract_slack(ch))
    when "signal"
      base.merge(extract_signal(ch))
    else
      base
    end
  end

  # --- Mattermost ---
  def extract_mattermost(ch)
    {
      chat_mode:  ch.dig("chatmode") || ch.dig("chatMode") || "onmessage",
      server_url: ch.dig("serverUrl") || ch.dig("server_url") || "",
      team:       ch.dig("team") || "",
      bot_token:  ch.dig("botToken").present? ? "••••set" : "not set"
    }
  end

  def apply_mattermost(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    mode = values[:chat_mode].to_s.strip
    config["chatmode"] = mode if %w[oncall onmessage onchar].include?(mode)

    url = values[:server_url].to_s.strip
    config["serverUrl"] = url if url.present? && url.match?(%r{\Ahttps?://})

    team = values[:team].to_s.strip.first(100)
    config["team"] = team if team.present?

    dm = values[:dm_scope].to_s.strip
    config["dmScope"] = dm if %w[user main].include?(dm)
  end

  # --- Slack ---
  def extract_slack(ch)
    {
      socket_mode:    ch.dig("socketMode") || ch.dig("socket_mode") || false,
      slash_commands: ch.dig("slashCommands") || ch.dig("slash_commands") || [],
      thread_mode:    ch.dig("threadMode") || ch.dig("thread_mode") || "reply",
      app_token:      ch.dig("appToken").present? ? "••••set" : "not set",
      bot_token:      ch.dig("botToken").present? ? "••••set" : "not set"
    }
  end

  def apply_slack(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    config["socketMode"] = ActiveModel::Type::Boolean.new.cast(values[:socket_mode]) if values.key?(:socket_mode)

    thread = values[:thread_mode].to_s.strip
    config["threadMode"] = thread if %w[reply broadcast none].include?(thread)

    dm = values[:dm_scope].to_s.strip
    config["dmScope"] = dm if %w[user main].include?(dm)
  end

  # --- Signal ---
  def extract_signal(ch)
    {
      reaction_mode:   ch.dig("reactionMode") || ch.dig("reaction_mode") || "off",
      group_handling:  ch.dig("groupHandling") || ch.dig("group_handling") || "respond",
      phone_number:    ch.dig("phoneNumber").present? ? "••••set" : "not set"
    }
  end

  def apply_signal(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    rm = values[:reaction_mode].to_s.strip
    config["reactionMode"] = rm if %w[off own all].include?(rm)

    gh = values[:group_handling].to_s.strip
    config["groupHandling"] = gh if %w[respond ignore mention_only].include?(gh)

    dm = values[:dm_scope].to_s.strip
    config["dmScope"] = dm if %w[user main].include?(dm)
  end
end
