# frozen_string_literal: true

# Manage environment variables for OpenClaw.
#
# OpenClaw reads env from multiple sources (.env, config inline, shell import)
# with ${VAR} substitution. This UI shows resolved vars (redacted),
# allows editing the .env file, and tests substitution.
class EnvManagerController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  ENV_FILE    = File.expand_path("~/.openclaw/.env")
  MAX_ENTRIES = 500
  MAX_KEY_LEN = 256
  MAX_VAL_LEN = 8192

  # GET /env_manager
  def show
    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}

    @env_config  = raw_conf.dig("env") || {}
    @shell_env   = raw_conf.dig("shellEnv") || raw_conf.dig("shell_env") || {}
    @env_file_exists = File.exist?(ENV_FILE)
    @env_entries     = parse_env_file
    @stats = {
      file_entries: @env_entries.size,
      config_inline: count_inline_env(raw_conf),
      shell_imports: @shell_env.is_a?(Hash) ? @shell_env.keys.size : 0
    }
  end

  # GET /env_manager/file — get raw .env contents (redacted)
  def file_contents
    unless File.exist?(ENV_FILE)
      return render json: { content: "", exists: false }
    end

    content = File.read(ENV_FILE, encoding: "utf-8")
    # Redact values for display
    redacted = content.lines.map do |line|
      line = line.chomp
      if line.match?(/\A\s*#/) || line.strip.empty?
        line
      elsif line.include?("=")
        key, _val = line.split("=", 2)
        "#{key}=••••••••"
      else
        line
      end
    end.join("\n")

    render json: { content: redacted, exists: true, line_count: content.lines.size }
  end

  # POST /env_manager/test — test variable substitution
  def test_substitution
    template = params[:template].to_s.strip.first(1000)

    if template.blank?
      return render json: { success: false, error: "Template is required" }, status: :unprocessable_entity
    end

    # Load .env to check substitution locally
    env = load_env_hash
    resolved = template.gsub(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/) do |match|
      key = Regexp.last_match(1)
      if env.key?(key)
        "#{key[0..2]}***"
      else
        "⚠️#{match}(NOT FOUND)"
      end
    end

    render json: {
      success: true,
      template: template,
      resolved: resolved,
      vars_found: template.scan(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/).flatten.uniq
    }
  end

  private

  def parse_env_file
    return [] unless File.exist?(ENV_FILE) && File.readable?(ENV_FILE)

    File.readlines(ENV_FILE, encoding: "utf-8").filter_map do |line|
      line = line.chomp.strip
      next if line.empty? || line.start_with?("#")
      next unless line.include?("=")

      key, _val = line.split("=", 2)
      key = key.strip
      next if key.empty?

      {
        key: key,
        has_value: _val.to_s.strip.present?,
        length: _val.to_s.strip.length
      }
    end.first(MAX_ENTRIES)
  rescue StandardError
    []
  end

  def load_env_hash
    return {} unless File.exist?(ENV_FILE) && File.readable?(ENV_FILE)

    hash = {}
    File.readlines(ENV_FILE, encoding: "utf-8").each do |line|
      line = line.chomp.strip
      next if line.empty? || line.start_with?("#")
      next unless line.include?("=")

      key, val = line.split("=", 2)
      key = key.strip
      val = val.to_s.strip
      # Remove surrounding quotes
      val = val[1..-2] if (val.start_with?('"') && val.end_with?('"')) || (val.start_with?("'") && val.end_with?("'"))
      hash[key] = val if key.present?
    end
    hash
  rescue StandardError
    {}
  end

  def count_inline_env(raw_conf)
    count = 0
    # Check for env vars referenced in config via ${VAR} pattern
    json_str = raw_conf.to_json rescue ""
    count = json_str.scan(/\$\{[A-Za-z_][A-Za-z0-9_]*\}/).uniq.size
    count
  end
end
