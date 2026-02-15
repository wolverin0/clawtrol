# frozen_string_literal: true

# Hot Reload Monitor for OpenClaw.
#
# OpenClaw has config hot reload with modes (hybrid/hot/restart/off) and debounce.
# This page shows: reload mode, recent reload events, which changes were
# hot-applied vs required restart, visual diff of config changes.
class HotReloadController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :ensure_gateway_configured!

  VALID_MODES = %w[hybrid hot restart off].freeze

  # GET /hot_reload
  def show
    raw_conf = current_raw_config

    @reload_config  = extract_reload_config(raw_conf)
    @health         = gateway_client.health
    @uptime         = extract_uptime(@health)
    @hot_fields     = hot_applicable_fields
    @restart_fields = restart_required_fields
  end

  # POST /hot_reload/update — update reload config
  def update
    values = params[:values]

    reload_conf = current_config_section("configReload")

    if values.is_a?(Hash) || values.is_a?(ActionController::Parameters)
      mode = values[:mode].to_s.strip
      reload_conf["mode"] = mode if VALID_MODES.include?(mode)

      debounce = values[:debounce_ms].to_i
      reload_conf["debounceMs"] = debounce.clamp(100, 30_000) if values.key?(:debounce_ms)

      if values.key?(:watch_config)
        reload_conf["watchConfig"] = ActiveModel::Type::Boolean.new.cast(values[:watch_config])
      end
    end

    apply_config_patch("configReload", reload_conf, reason: "Hot reload config updated from ClawTrol")
  end

  private

  def extract_reload_config(raw_conf)
    rc = raw_conf["configReload"] || raw_conf["config_reload"] || {}
    {
      mode:         rc["mode"] || "hybrid",
      debounce_ms:  rc["debounceMs"] || rc["debounce_ms"] || 2000,
      watch_config: rc.fetch("watchConfig", rc.fetch("watch_config", true))
    }
  end

  def extract_uptime(health)
    return "unknown" unless health.is_a?(Hash)

    started = health["startedAt"] || health["started_at"]
    return "unknown" unless started

    begin
      start_time = Time.parse(started.to_s)
      elapsed = Time.now - start_time
      if elapsed < 60
        "#{elapsed.to_i}s"
      elsif elapsed < 3600
        "#{(elapsed / 60).to_i}m"
      else
        "#{(elapsed / 3600).to_i}h #{((elapsed % 3600) / 60).to_i}m"
      end
    rescue StandardError
      "unknown"
    end
  end

  # Fields that can be hot-applied without restart
  def hot_applicable_fields
    [
      { field: "identity.name",       desc: "Bot name" },
      { field: "identity.emoji",      desc: "Bot emoji" },
      { field: "messages.*",          desc: "Message prefixes and ack reactions" },
      { field: "session.sendPolicy",  desc: "Send policy rules" },
      { field: "session.accessGroups", desc: "Access groups" },
      { field: "skills.*",           desc: "Skill enable/disable/config" },
      { field: "hooks.mappings",     desc: "Webhook mappings" },
      { field: "cron.*",             desc: "Cron job definitions" },
      { field: "logging.*",          desc: "Log levels and style" },
      { field: "heartbeat.*",        desc: "Heartbeat config" }
    ]
  end

  # Fields that require full restart
  def restart_required_fields
    [
      { field: "channels.*",          desc: "Channel connections (Telegram/Discord/etc)" },
      { field: "models.provider",     desc: "Model provider settings" },
      { field: "models.default",      desc: "Default model" },
      { field: "sandbox.*",           desc: "Docker sandbox config" },
      { field: "tools.*",             desc: "Tool availability" },
      { field: "session.store",       desc: "Session storage backend" },
      { field: "exec.*",              desc: "Exec security settings" },
      { field: "plugins.*",           desc: "Plugin loading" }
    ]
  end
end
