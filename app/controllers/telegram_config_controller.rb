# frozen_string_literal: true

# Visual configuration page for OpenClaw's Telegram channel plugin.
#
# Telegram plugin supports: customCommands, draftChunk streaming,
# linkPreview, streamMode (off/partial/block), retry policy,
# webhook mode, proxy, per-topic config with skills + systemPrompt.
class TelegramConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  MAX_SYSTEM_PROMPT = 10_000
  MAX_COMMAND_NAME  = 64
  MAX_COMMAND_DESC  = 256

  # GET /telegram_config
  def show
    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}

    @channels     = raw_conf.dig("channels") || {}
    @telegram     = extract_telegram_config(@channels)
    @health       = gateway_client.health
    @channel_status = gateway_client.channels_status
  end

  # POST /telegram_config/update — patch Telegram channel config
  def update
    section = params[:section].to_s.strip
    values  = params[:values]

    unless %w[streaming commands linkPreview topics proxy retry general].include?(section)
      return render json: { success: false, error: "Unknown section: #{section}" }, status: :unprocessable_entity
    end

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    channels = (raw_conf["channels"] || {}).deep_dup

    tg_key = find_telegram_key(channels)
    channels[tg_key] ||= {}

    case section
    when "streaming"
      apply_streaming(channels[tg_key], values)
    when "commands"
      apply_commands(channels[tg_key], values)
    when "linkPreview"
      apply_link_preview(channels[tg_key], values)
    when "topics"
      apply_topics(channels[tg_key], values)
    when "proxy"
      apply_proxy(channels[tg_key], values)
    when "retry"
      apply_retry(channels[tg_key], values)
    when "general"
      apply_general(channels[tg_key], values)
    end

    patch  = { "channels" => channels }
    result = gateway_client.config_patch(
      raw:    patch.to_json,
      reason: "Telegram config (#{section}) updated from ClawTrol"
    )

    if result["error"].present?
      render json: { success: false, error: result["error"] }, status: :unprocessable_entity
    else
      render json: { success: true, message: "Telegram #{section} config saved. Gateway restarting…" }
    end
  end

  private

  def find_telegram_key(channels)
    channels.keys.find { |k| k.to_s.match?(/telegram/i) } || "telegram"
  end

  def extract_telegram_config(channels)
    tg_key = find_telegram_key(channels)
    tg     = channels[tg_key] || {}

    {
      key:            tg_key,
      stream_mode:    tg.dig("streamMode") || tg.dig("stream_mode") || "block",
      draft_chunk:    tg.dig("draftChunk") || tg.dig("draft_chunk") || false,
      link_preview:   tg.dig("linkPreview") || {},
      custom_commands: extract_commands(tg),
      topics:         tg.dig("topics") || {},
      proxy:          tg.dig("proxy") || {},
      retry_policy:   tg.dig("retry") || tg.dig("retryPolicy") || {},
      webhook_mode:   tg.dig("webhookMode") || tg.dig("webhook_mode"),
      dm_scope:       tg.dig("dmScope") || "user",
      allowFrom:      tg.dig("allowFrom") || [],
      raw:            tg
    }
  end

  def extract_commands(tg)
    cmds = tg.dig("customCommands") || tg.dig("custom_commands") || []
    Array(cmds).map do |cmd|
      if cmd.is_a?(Hash)
        { name: cmd["command"] || cmd["name"], description: cmd["description"] }
      else
        { name: cmd.to_s, description: "" }
      end
    end
  end

  def apply_streaming(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    mode = values[:stream_mode].to_s.strip
    config["streamMode"] = mode if %w[off partial block].include?(mode)
    config["draftChunk"] = ActiveModel::Type::Boolean.new.cast(values[:draft_chunk]) if values.key?(:draft_chunk)
  end

  def apply_commands(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    commands = values[:commands]
    return unless commands.is_a?(Array) || commands.is_a?(ActionController::Parameters)

    sanitized = Array(commands).first(50).filter_map do |cmd|
      name = cmd["name"].to_s.strip.first(MAX_COMMAND_NAME)
      desc = cmd["description"].to_s.strip.first(MAX_COMMAND_DESC)
      next if name.blank?

      { "command" => name, "description" => desc }
    end

    config["customCommands"] = sanitized
  end

  def apply_link_preview(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    lp = config["linkPreview"] || {}
    lp["disabled"] = ActiveModel::Type::Boolean.new.cast(values[:disabled]) if values.key?(:disabled)
    lp["preferSmall"] = ActiveModel::Type::Boolean.new.cast(values[:prefer_small]) if values.key?(:prefer_small)
    config["linkPreview"] = lp
  end

  def apply_topics(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    topics = values[:topics]
    return unless topics.is_a?(Hash) || topics.is_a?(ActionController::Parameters)

    sanitized = {}
    topics.each do |topic_id, topic_conf|
      next unless topic_id.to_s.match?(/\A\d{1,20}\z/)

      entry = {}
      if topic_conf.is_a?(Hash) || topic_conf.is_a?(ActionController::Parameters)
        entry["skills"]       = Array(topic_conf["skills"]).first(20).map { |s| s.to_s.first(100) } if topic_conf["skills"].present?
        entry["systemPrompt"] = topic_conf["systemPrompt"].to_s.first(MAX_SYSTEM_PROMPT) if topic_conf["systemPrompt"].present?
      end
      sanitized[topic_id.to_s] = entry
    end

    config["topics"] = sanitized
  end

  def apply_proxy(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    proxy = {}
    url = values[:url].to_s.strip
    proxy["url"] = url if url.present? && url.match?(%r{\Ahttps?://})
    config["proxy"] = proxy
  end

  def apply_retry(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    retry_conf = {}
    max = values[:maxRetries].to_i
    retry_conf["maxRetries"] = max.clamp(0, 10) if values.key?(:maxRetries)
    delay = values[:delayMs].to_i
    retry_conf["delayMs"] = delay.clamp(100, 30_000) if values.key?(:delayMs)
    config["retry"] = retry_conf
  end

  def apply_general(config, values)
    return unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    config["webhookMode"] = ActiveModel::Type::Boolean.new.cast(values[:webhook_mode]) if values.key?(:webhook_mode)
    config["dmScope"] = values[:dm_scope].to_s.strip if %w[user main].include?(values[:dm_scope].to_s.strip)
  end
end
