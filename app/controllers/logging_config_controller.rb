# frozen_string_literal: true

# Logging & Debug config page for OpenClaw.
#
# OpenClaw has `logging` (level, file, consoleLevel, consoleStyle, redactSensitive)
# and debug commands. This provides a log viewer and config editor.
class LoggingConfigController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :ensure_gateway_configured!

  VALID_LEVELS   = %w[error warn info verbose debug trace].freeze
  VALID_STYLES   = %w[pretty json minimal].freeze
  MAX_LOG_LINES  = 500

  # GET /logging_config
  def show
    raw_conf = current_raw_config

    @logging   = extract_logging(raw_conf)
    @debug     = extract_debug(raw_conf)
    @health    = gateway_client.health
  end

  # POST /logging_config/update — patch logging config
  def update
    section = params[:section].to_s.strip
    values  = params[:values]

    validate_section!(section, allowed: %w[logging debug]) or return

    raw_conf = current_raw_config

    case section
    when "logging"
      data = build_logging_patch(raw_conf, values)
      apply_config_patch("logging", data, reason: "Logging config updated from ClawTrol")
    when "debug"
      data = build_debug_patch(raw_conf, values)
      apply_config_patch("debug", data, reason: "Debug config updated from ClawTrol")
    end
  end

  # GET /logging_config/tail — fetch recent log lines
  def tail
    lines_count = [params[:lines].to_i, MAX_LOG_LINES].min
    lines_count = 50 if lines_count <= 0
    level_filter = params[:level].to_s.strip.presence

    health = gateway_client.health
    log_file = health.dig("logFile") || health.dig("log_file")

    log_lines = []
    if log_file.present? && File.exist?(log_file) && File.readable?(log_file)
      raw = File.readlines(log_file, encoding: "utf-8").last(lines_count)
      log_lines = raw.map(&:chomp)

      if level_filter.present?
        log_lines = log_lines.select { |l| l.include?(level_filter.upcase) || l.include?(level_filter.downcase) }
      end
    end

    render json: { lines: log_lines, count: log_lines.size, source: log_file || "unavailable" }
  end

  private

  def extract_logging(raw_conf)
    log = raw_conf["logging"] || {}
    {
      level:            log["level"] || "info",
      file:             log["file"],
      console_level:    log["consoleLevel"] || log["console_level"] || "info",
      console_style:    log["consoleStyle"] || log["console_style"] || "pretty",
      redact_sensitive: log.fetch("redactSensitive", log.fetch("redact_sensitive", true))
    }
  end

  def extract_debug(raw_conf)
    dbg = raw_conf["debug"] || {}
    {
      enabled:    dbg.fetch("enabled", false),
      bash:       dbg.fetch("bash", false),
      allow_eval: dbg.fetch("allowEval", dbg.fetch("allow_eval", false))
    }
  end

  def build_logging_patch(raw_conf, values)
    return raw_conf["logging"] || {} unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    current = (raw_conf["logging"] || {}).dup

    level = values[:level].to_s.strip
    current["level"] = level if VALID_LEVELS.include?(level)

    cl = values[:console_level].to_s.strip
    current["consoleLevel"] = cl if VALID_LEVELS.include?(cl)

    cs = values[:console_style].to_s.strip
    current["consoleStyle"] = cs if VALID_STYLES.include?(cs)

    if values.key?(:redact_sensitive)
      current["redactSensitive"] = ActiveModel::Type::Boolean.new.cast(values[:redact_sensitive])
    end

    file = values[:file].to_s.strip
    if file.present?
      if file.match?(%r{\A[a-zA-Z0-9_./-]{1,256}\z}) && !file.include?("..")
        current["file"] = file
      end
    elsif values.key?(:file) && file.blank?
      current.delete("file")
    end

    current
  end

  def build_debug_patch(raw_conf, values)
    return raw_conf["debug"] || {} unless values.is_a?(Hash) || values.is_a?(ActionController::Parameters)

    current = (raw_conf["debug"] || {}).dup

    current["enabled"]   = ActiveModel::Type::Boolean.new.cast(values[:enabled]) if values.key?(:enabled)
    current["bash"]      = ActiveModel::Type::Boolean.new.cast(values[:bash]) if values.key?(:bash)
    current["allowEval"] = ActiveModel::Type::Boolean.new.cast(values[:allow_eval]) if values.key?(:allow_eval)

    current
  end
end
