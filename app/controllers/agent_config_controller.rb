# frozen_string_literal: true

# Multi-Agent Config UI: view and manage OpenClaw multi-agent configurations.
#
# OpenClaw supports isolated agents with separate workspaces, models, sessions,
# auth, and channel bindings. This controller reads the gateway config and
# presents a visual editor for agent definitions and channel→agent routing.
class AgentConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /agents/config
  def show
    @config_data = gateway_client.config_get
    @health_data = gateway_client.health
    @agents_list = gateway_client.agents_list
    @channels_status = gateway_client.channels_status

    # Extract agent definitions from config
    @agents = extract_agents(@config_data)
    @channel_bindings = extract_channel_bindings(@config_data)
    @tool_profiles = extract_tool_profiles(@config_data)
    @available_models = extract_available_models(@config_data, @health_data)

    # Default agent (main) info
    @default_agent = build_default_agent(@config_data, @health_data)
  end

  # PATCH /agents/config/update_agent
  def update_agent
    agent_id = params[:agent_id].to_s.strip
    if agent_id.blank?
      render json: { success: false, error: "Agent ID required" }, status: :unprocessable_entity
      return
    end

    # Sanitize agent_id — alphanumeric, hyphens, underscores only
    unless agent_id.match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
      render json: { success: false, error: "Invalid agent ID format" }, status: :unprocessable_entity
      return
    end

    patch = build_agent_patch(agent_id, agent_params)
    result = gateway_client.config_patch(raw: patch.to_json, reason: "Agent #{agent_id} updated from ClawTrol")

    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Agent '#{agent_id}' updated. Gateway restarting..." }
    end
  end

  # PATCH /agents/config/update_bindings
  def update_bindings
    bindings = params[:bindings]
    unless bindings.is_a?(ActionController::Parameters) || bindings.is_a?(Hash)
      render json: { success: false, error: "Invalid bindings format" }, status: :unprocessable_entity
      return
    end

    patch = { "agents" => { "bindings" => bindings.to_unsafe_h } }
    result = gateway_client.config_patch(raw: patch.to_json, reason: "Channel bindings updated from ClawTrol")

    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Channel bindings updated. Gateway restarting..." }
    end
  end

  private

  def agent_params
    params.permit(:workspace, :model, :tool_profile, :system_prompt, :compaction_mode)
  end

  def extract_agents(config)
    return [] unless config.is_a?(Hash) && config["error"].blank?

    agents_config = config.dig("config", "agents") || config["agents"]
    return [] unless agents_config.is_a?(Hash)

    definitions = agents_config["definitions"] || agents_config["agents"] || {}
    return [] unless definitions.is_a?(Hash)

    definitions.map do |id, agent_def|
      agent_def = agent_def.is_a?(Hash) ? agent_def : {}
      {
        id: id,
        workspace: agent_def["workspace"],
        model: agent_def["model"] || agent_def["defaultModel"],
        tool_profile: agent_def["toolProfile"] || agent_def["tools"],
        system_prompt: agent_def["systemPrompt"],
        compaction_mode: agent_def["compaction"],
        session: agent_def["session"],
        auth: agent_def["auth"],
        enabled: agent_def.fetch("enabled", true)
      }
    end
  end

  def extract_channel_bindings(config)
    return {} unless config.is_a?(Hash) && config["error"].blank?

    agents_config = config.dig("config", "agents") || config["agents"]
    return {} unless agents_config.is_a?(Hash)

    agents_config["bindings"] || agents_config["channelBindings"] || {}
  end

  def extract_tool_profiles(config)
    return {} unless config.is_a?(Hash) && config["error"].blank?

    raw_config = config.dig("config") || config
    raw_config["toolProfiles"] || {}
  end

  def extract_available_models(config, health)
    models = []

    # From config allowlist
    raw_config = config.is_a?(Hash) ? (config.dig("config") || config) : {}
    if raw_config["models"].is_a?(Array)
      models.concat(raw_config["models"].map(&:to_s))
    end

    # Default model
    default = raw_config["defaultModel"]
    models << default.to_s if default.present?

    # From health data
    if health.is_a?(Hash) && health["models"].is_a?(Array)
      models.concat(health["models"].map(&:to_s))
    end

    models.uniq.reject(&:blank?).sort
  end

  def build_default_agent(config, health)
    raw_config = config.is_a?(Hash) ? (config.dig("config") || config) : {}

    {
      id: "main",
      workspace: raw_config["workspace"] || "~/.openclaw/workspace",
      model: raw_config["defaultModel"] || "default",
      tool_profile: raw_config["toolProfile"] || "full",
      compaction_mode: raw_config.dig("session", "compactionMode") || "auto",
      version: health.is_a?(Hash) ? health["version"] : nil,
      uptime: health.is_a?(Hash) ? health["uptime"] : nil
    }
  end

  def build_agent_patch(agent_id, params)
    agent_def = {}
    agent_def["workspace"] = params[:workspace] if params[:workspace].present?
    agent_def["model"] = params[:model] if params[:model].present?
    agent_def["toolProfile"] = params[:tool_profile] if params[:tool_profile].present?
    agent_def["systemPrompt"] = params[:system_prompt] if params[:system_prompt].present?
    agent_def["compaction"] = params[:compaction_mode] if params[:compaction_mode].present?

    {
      "agents" => {
        "definitions" => {
          agent_id => agent_def
        }
      }
    }
  end
end
