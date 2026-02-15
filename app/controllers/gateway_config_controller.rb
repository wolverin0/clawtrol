# frozen_string_literal: true

class GatewayConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /gateway/config — show current config with editor
  def show
    @config_data = gateway_client.config_get
    @health_data = gateway_client.health
    @config_raw = @config_data.is_a?(Hash) ? JSON.pretty_generate(@config_data) : @config_data.to_s

    # Parse config sections for structured display
    @sections = extract_config_sections(@config_data)
  end

  # POST /gateway/config/apply — replace full config
  MAX_CONFIG_SIZE = 256.kilobytes

  def apply
    raw = params[:config_raw].to_s.strip
    reason = params[:reason].to_s.strip.presence || "Config update from ClawTrol"

    if raw.blank?
      render json: { success: false, error: "Config cannot be empty" }, status: :unprocessable_entity
      return
    end

    if raw.bytesize > MAX_CONFIG_SIZE
      render json: { success: false, error: "Config too large (max #{MAX_CONFIG_SIZE / 1024}KB)" }, status: :unprocessable_entity
      return
    end

    # Validate JSON/YAML before sending
    begin
      JSON.parse(raw)
    rescue JSON::ParserError
      begin
        require "yaml"
        YAML.safe_load(raw, permitted_classes: [Symbol, Date, Time])
      rescue StandardError => e
        render json: { success: false, error: "Invalid config format: #{e.message}" }, status: :unprocessable_entity
        return
      end
    end

    result = gateway_client.config_apply(raw: raw, reason: reason)
    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Config applied. Gateway restarting..." }
    end
  end

  # POST /gateway/config/patch — merge partial config
  def patch_config
    raw = params[:config_raw].to_s.strip
    reason = params[:reason].to_s.strip.presence || "Config patch from ClawTrol"

    if raw.blank?
      render json: { success: false, error: "Patch cannot be empty" }, status: :unprocessable_entity
      return
    end

    if raw.bytesize > MAX_CONFIG_SIZE
      render json: { success: false, error: "Patch too large (max #{MAX_CONFIG_SIZE / 1024}KB)" }, status: :unprocessable_entity
      return
    end

    # Validate JSON/YAML before sending (same as apply)
    begin
      JSON.parse(raw)
    rescue JSON::ParserError
      begin
        require "yaml"
        YAML.safe_load(raw, permitted_classes: [Symbol, Date, Time])
      rescue StandardError => e
        render json: { success: false, error: "Invalid patch format: #{e.message}" }, status: :unprocessable_entity
        return
      end
    end

    result = gateway_client.config_patch(raw: raw, reason: reason)
    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Config patched. Gateway restarting..." }
    end
  end

  # POST /gateway/config/restart — restart gateway
  def restart
    reason = params[:reason].to_s.strip.presence || "Manual restart from ClawTrol"
    result = gateway_client.gateway_restart(reason: reason)
    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Gateway restart initiated" }
    end
  end

  private

  # Extract meaningful sections from config for structured display
  def extract_config_sections(config)
    return [] unless config.is_a?(Hash) && config["error"].blank?

    sections = []

    # Models section
    if config["models"].present? || config["defaultModel"].present?
      sections << {
        name: "Models",
        icon: "🤖",
        key: "models",
        data: {
          default: config["defaultModel"],
          models: config["models"]
        },
        description: "Default model and model allowlist"
      }
    end

    # Channels section
    if config["channels"].present? || config["telegram"].present? || config["discord"].present?
      sections << {
        name: "Channels",
        icon: "📡",
        key: "channels",
        data: config.slice("channels", "telegram", "discord", "whatsapp", "signal", "slack"),
        description: "Messaging channel configurations"
      }
    end

    # Hooks section
    if config["hooks"].present?
      sections << {
        name: "Hooks",
        icon: "🪝",
        key: "hooks",
        data: config["hooks"],
        description: "Webhook mappings and hook configuration"
      }
    end

    # Cron section
    if config["cron"].present?
      sections << {
        name: "Cron Jobs",
        icon: "⏰",
        key: "cron",
        data: config["cron"],
        description: "Scheduled tasks and cron configuration"
      }
    end

    # Tools section
    if config["tools"].present? || config["toolPolicy"].present?
      sections << {
        name: "Tools",
        icon: "🔧",
        key: "tools",
        data: config.slice("tools", "toolPolicy", "toolProfiles"),
        description: "Tool availability and profiles"
      }
    end

    # Session section
    if config["session"].present?
      sections << {
        name: "Session",
        icon: "💬",
        key: "session",
        data: config["session"],
        description: "Session settings (DM scope, compaction, identity links)"
      }
    end

    # Plugins section
    if config["plugins"].present?
      sections << {
        name: "Plugins",
        icon: "🔌",
        key: "plugins",
        data: config["plugins"],
        description: "Installed and enabled plugins"
      }
    end

    sections
  end
end
