# frozen_string_literal: true

# Visual configuration page for OpenClaw's Discord channel plugin.
#
# Discord plugin supports: guild-level config, per-channel allow/mention/skills/systemPrompt,
# per-user allowlist, reaction notification modes, actions toggles
# (reactions/stickers/polls/permissions/threads/pins/search/moderation),
# maxLinesPerMessage.
class DiscordConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  MAX_SYSTEM_PROMPT  = 10_000
  MAX_CHANNEL_ID     = 30
  MAX_GUILD_ID       = 30

  # GET /discord_config
  def show
    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}

    @channels       = raw_conf.dig("channels") || {}
    @discord        = extract_discord_config(@channels)
    @health         = gateway_client.health
    @channel_status = gateway_client.channels_status
  end

  # POST /discord_config/update — patch Discord channel config
  def update
    section = params[:section].to_s.strip
    values  = params[:values]

    unless %w[general guilds actions reactions users].include?(section)
      return render json: { success: false, error: "Unknown section: #{section}" }, status: :unprocessable_entity
    end

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    channels = (raw_conf["channels"] || {}).deep_dup

    dc_key = find_discord_key(channels)
    channels[dc_key] ||= {}

    case section
    when "general"
      apply_general(channels[dc_key], values)
    when "guilds"
      apply_guilds(channels[dc_key], values)
    when "actions"
      apply_actions(channels[dc_key], values)
    when "reactions"
      apply_reactions(channels[dc_key], values)
    when "users"
      apply_users(channels[dc_key], values)
    end

    patch  = { "channels" => channels }
    result = gateway_client.config_patch(
      raw:    patch.to_json,
      reason: "Discord config (#{section}) updated from ClawTrol"
    )

    if result["error"].present?
      render json: { success: false, error: result["error"] }, status: :unprocessable_entity
    else
      render json: { success: true, message: "Discord #{section} config saved. Gateway restarting…" }
    end
  end

  private

  def find_discord_key(channels)
    channels.keys.find { |k| k.to_s.match?(/discord/i) } || "discord"
  end

  def extract_discord_config(channels)
    dc_key = find_discord_key(channels)
    dc     = channels[dc_key] || {}

    {
      key:                dc_key,
      max_lines:          dc.dig("maxLinesPerMessage") || dc.dig("max_lines_per_message") || 40,
      dm_scope:           dc.dig("dmScope") || "user",
      guilds:             dc.dig("guilds") || {},
      actions:            extract_actions(dc),
      reaction_mode:      dc.dig("reactionNotifications") || dc.dig("reaction_notifications") || "off",
      allowlist_users:    dc.dig("allowFrom") || [],
      stream_mode:        dc.dig("streamMode") || "off",
      raw:                dc
    }
  end

  def extract_actions(dc)
    acts = dc.dig("actions") || {}
    default_actions = %w[reactions stickers polls permissions threads pins search moderation]
    default_actions.map do |act|
      { name: act, enabled: acts.fetch(act, true) }
    end
  end

  def apply_general(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    max_lines = values[:max_lines].to_i
    config["maxLinesPerMessage"] = max_lines.clamp(5, 200) if values.key?(:max_lines)

    dm = values[:dm_scope].to_s.strip
    config["dmScope"] = dm if %w[user main].include?(dm)

    mode = values[:stream_mode].to_s.strip
    config["streamMode"] = mode if %w[off partial block].include?(mode)
  end

  def apply_guilds(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    guilds_data = values[:guilds]
    return unless guilds_data.is_a?(Hash) || guilds_data.is_a?(ActionController::Parameters)

    sanitized = {}
    guilds_data.each do |guild_id, guild_conf|
      next unless guild_id.to_s.match?(/\A\d{1,30}\z/)
      next unless guild_conf.is_a?(Hash) || guild_conf.is_a?(ActionController::Parameters)

      entry = {}

      # Per-channel config
      if guild_conf["channels"].is_a?(Hash) || guild_conf["channels"].is_a?(ActionController::Parameters)
        ch_conf = {}
        guild_conf["channels"].each do |ch_id, ch_val|
          next unless ch_id.to_s.match?(/\A\d{1,30}\z/)

          ch_entry = {}
          ch_entry["allow"]        = ActiveModel::Type::Boolean.new.cast(ch_val["allow"]) if ch_val.key?("allow")
          ch_entry["mention"]      = ActiveModel::Type::Boolean.new.cast(ch_val["mention"]) if ch_val.key?("mention")
          ch_entry["skills"]       = Array(ch_val["skills"]).first(20).map { |s| s.to_s.first(100) } if ch_val["skills"].present?
          ch_entry["systemPrompt"] = ch_val["systemPrompt"].to_s.first(MAX_SYSTEM_PROMPT) if ch_val["systemPrompt"].present?
          ch_conf[ch_id.to_s] = ch_entry
        end
        entry["channels"] = ch_conf
      end

      sanitized[guild_id.to_s] = entry
    end

    config["guilds"] = sanitized
  end

  def apply_actions(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    actions_hash = values[:actions]
    return unless actions_hash.is_a?(Hash) || actions_hash.is_a?(ActionController::Parameters)

    sanitized = {}
    %w[reactions stickers polls permissions threads pins search moderation].each do |act|
      sanitized[act] = ActiveModel::Type::Boolean.new.cast(actions_hash[act]) if actions_hash.key?(act)
    end

    config["actions"] = sanitized
  end

  def apply_reactions(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    mode = values[:mode].to_s.strip
    config["reactionNotifications"] = mode if %w[off own all allowlist].include?(mode)
  end

  def apply_users(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    users_list = values[:allowFrom]
    return unless users_list.is_a?(Array) || users_list.is_a?(ActionController::Parameters)

    sanitized = Array(users_list).first(200).filter_map do |uid|
      uid.to_s.strip.presence&.first(30)
    end.select { |u| u.match?(/\A\d{1,30}\z/) }

    config["allowFrom"] = sanitized
  end
end
