# frozen_string_literal: true

require "json"
require "fileutils"

module Zerobitch
  class ConfigGenerator
    BASE_CONFIG_PATH = File.expand_path("~/zeroclaw-fleet/base-config.toml")
    STORAGE_DIR = Rails.root.join("storage", "zerobitch")
    BASE_DIR = STORAGE_DIR

    DEFAULT_AGENTS_MD = <<~MARKDOWN
      # AGENTS.md

      This workspace is managed by ZeroBitch Fleet.

      - Keep outputs concise and actionable.
      - Persist relevant findings in memory.
      - Follow SOUL.md role and boundaries.
    MARKDOWN

    # Params: provider, model, api_key, autonomy (supervised/full),
    # allowed_commands (array), gateway_port, gateway_host
    def self.generate_config(agent_id, params)
      config = File.read(BASE_CONFIG_PATH)

      autonomy = params[:autonomy].presence || "supervised"
      gateway_port = params[:gateway_port].presence || 8080
      gateway_host = "0.0.0.0"

      provider = resolve_provider(params[:provider])
      model = resolved_model(params[:provider], params[:model])
      allowed_commands = Array(params[:allowed_commands])

      config = replace_string(config, /^api_key\s*=\s*".*"$/, "api_key = #{params[:api_key].to_s.to_json}")
      config = replace_string(config, /^default_provider\s*=\s*".*"$/, "default_provider = #{provider.to_json}")
      config = replace_string(config, /^default_model\s*=\s*".*"$/, "default_model = #{model.to_json}")
      config = replace_string(config, /^level\s*=\s*".*"$/, "level = #{autonomy.to_json}")
      config = replace_string(config, /^allowed_commands\s*=\s*\[[\s\S]*?\]\nforbidden_paths\s*=/m, "allowed_commands = #{allowed_commands.to_json}\nforbidden_paths =")
      config = replace_string(config, /^port\s*=\s*\d+$/, "port = #{gateway_port}")
      config = replace_string(config, /^host\s*=\s*".*"$/, "host = #{gateway_host.to_json}")
      config = replace_string(config, /^require_pairing\s*=\s*(true|false)$/, "require_pairing = false")

      if autonomy == "full"
        config = replace_string(config, /^max_actions_per_hour\s*=\s*\d+$/, "max_actions_per_hour = 100")
        config = replace_string(config, /^block_high_risk_commands\s*=\s*(true|false)$/, "block_high_risk_commands = false")
        config = replace_string(config, /^require_approval_for_medium_risk\s*=\s*(true|false)$/, "require_approval_for_medium_risk = false")
      else
        config = replace_string(config, /^max_actions_per_hour\s*=\s*\d+$/, "max_actions_per_hour = 20")
        config = replace_string(config, /^block_high_risk_commands\s*=\s*(true|false)$/, "block_high_risk_commands = true")
        config = replace_string(config, /^require_approval_for_medium_risk\s*=\s*(true|false)$/, "require_approval_for_medium_risk = true")
      end

      output_dir = STORAGE_DIR.join("configs", agent_id.to_s)
      FileUtils.mkdir_p(output_dir)

      output_path = output_dir.join("config.toml")
      File.write(output_path, config)
      output_path
    end

    # Create workspace directory with SOUL.md and AGENTS.md
    def self.generate_workspace(agent_id, soul_content:, agents_content: "")
      workspace_path = STORAGE_DIR.join("workspaces", agent_id.to_s)
      FileUtils.mkdir_p(workspace_path)

      File.write(workspace_path.join("SOUL.md"), soul_content.to_s)
      File.write(workspace_path.join("AGENTS.md"), agents_content.presence || DEFAULT_AGENTS_MD)

      workspace_path
    end

    # Map friendly names to ZeroClaw provider strings
    def self.resolve_provider(provider_name)
      provider = provider_name.to_s.downcase.strip

      case provider
      when "groq", "openrouter"
        "openrouter"
      when "cerebras"
        "custom:https://api.cerebras.ai/v1"
      when "mistral"
        "custom:https://api.mistral.ai/v1"
      when "ollama"
        "ollama"
      when "openai"
        "openai"
      when "anthropic"
        "anthropic"
      else
        provider_name.to_s
      end
    end

    def self.resolved_model(provider_name, model_name)
      provider = provider_name.to_s.downcase.strip
      model = model_name.to_s

      return model if provider != "groq" || model.blank?
      return model if model.start_with?("groq/")

      "groq/#{model}"
    end
    private_class_method :resolved_model

    def self.replace_string(content, pattern, replacement)
      content.sub(pattern, replacement)
    end
    private_class_method :replace_string
  end
end
