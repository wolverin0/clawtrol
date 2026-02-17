# frozen_string_literal: true

require "securerandom"

class ZerobitchController < ApplicationController
  before_action :require_authentication

  EMOJI_POOL = %w[🤖 🦎 📡 🛡️ 📝 🔍 🧮].freeze
  DEFAULT_ALLOWED_COMMANDS = %w[curl docker ls cat grep jq awk sed ps top git find tail head].freeze
  PROVIDER_MODELS = {
    "openrouter" => ["anthropic/claude-3.5-sonnet", "openai/gpt-4o-mini", "meta-llama/llama-3.3-70b-instruct"],
    "groq" => ["llama-3.3-70b-versatile", "mixtral-8x7b-32768", "deepseek-r1-distill-llama-70b"],
    "cerebras" => ["llama3.1-8b", "llama3.3-70b"],
    "mistral" => ["mistral-large-latest", "ministral-8b-latest", "codestral-latest"],
    "ollama" => ["llama3.2", "qwen2.5-coder", "deepseek-r1"]
  }.freeze

  # GET /zerobitch
  def index
    @agents = fleet_agents
    @summary = fleet_summary(@agents)

    respond_to do |format|
      format.html
      format.json { render json: { success: true, agents: @agents, summary: @summary } }
    end
  end

  # GET /zerobitch/agents/new
  def new_agent
    @default_emoji = EMOJI_POOL.sample
    @allowed_commands = DEFAULT_ALLOWED_COMMANDS
    @provider_models = PROVIDER_MODELS
    @soul_templates = soul_templates
  end

  # POST /zerobitch/agents
  def create_agent
    attrs = create_agent_params
    agent_id = normalize_agent_id(attrs[:name])
    api_key = attrs[:api_key_mode] == "custom" ? attrs[:custom_api_key] : ENV.fetch("OPENROUTER_API_KEY", "")

    config_path = Zerobitch::ConfigGenerator.generate_config(agent_id, {
      provider: attrs[:provider],
      model: attrs[:model],
      api_key: api_key,
      autonomy: attrs[:autonomy],
      allowed_commands: attrs[:allowed_commands],
      gateway_port: 8080
    })

    workspace_path = Zerobitch::ConfigGenerator.generate_workspace(
      agent_id,
      soul_content: attrs[:soul_content],
      agents_content: attrs[:agents_content]
    )

    agent = Zerobitch::AgentRegistry.create(
      id: agent_id,
      name: attrs[:name],
      emoji: attrs[:emoji],
      role: attrs[:role],
      provider: attrs[:provider],
      model: attrs[:model],
      mode: attrs[:mode],
      autonomy: attrs[:autonomy],
      mem_limit: attrs[:mem_limit],
      cpu_limit: attrs[:cpu_limit],
      allowed_commands: attrs[:allowed_commands],
      api_key_name: attrs[:api_key_mode] == "custom" ? "custom" : "fleet_default"
    )

    run_result = Zerobitch::DockerService.run(
      name: agent[:id],
      config_path: config_path,
      workspace_path: workspace_path,
      port: agent[:port],
      mem_limit: agent[:mem_limit],
      cpu_limit: agent[:cpu_limit],
      command: agent[:mode] == "gateway" ? "gateway" : "daemon"
    )

    unless run_result[:success]
      Zerobitch::AgentRegistry.destroy(agent[:id])
      return redirect_to new_zerobitch_agent_path, alert: "Agent created in registry but container failed: #{run_result[:error].presence || 'unknown error'}"
    end

    redirect_to zerobitch_agent_path(agent[:id]), notice: "Agent #{agent[:name]} created and started."
  rescue StandardError => e
    redirect_to new_zerobitch_agent_path, alert: "Failed to create agent: #{e.message}"
  end

  # GET /zerobitch/agents/:id
  def show_agent
    @agent_id = params[:id]
  end

  # DELETE /zerobitch/agents/:id
  def destroy_agent
    result = Zerobitch::DockerService.remove(params[:id])
    registry_removed = Zerobitch::AgentRegistry.destroy(params[:id])

    respond_to do |format|
      format.html do
        if registry_removed
          redirect_to zerobitch_path, notice: "Agent #{params[:id]} deleted."
        else
          redirect_to zerobitch_path, alert: "Agent #{params[:id]} not found in registry."
        end
      end
      format.json { render json: { success: result[:success] || registry_removed, id: params[:id], action: "delete" } }
    end
  end

  # POST /zerobitch/agents/:id/start
  def start_agent
    handle_agent_action(:start)
  end

  # POST /zerobitch/agents/:id/stop
  def stop_agent
    handle_agent_action(:stop)
  end

  # POST /zerobitch/agents/:id/restart
  def restart_agent
    handle_agent_action(:restart)
  end

  # POST /zerobitch/agents/:id/task
  def send_task
    redirect_to zerobitch_agent_tasks_path(params[:id]), notice: "Task dispatch stub ready for #{params[:id]}."
  end

  # GET /zerobitch/agents/:id/logs
  def logs
    @agent_id = params[:id]
  end

  # GET /zerobitch/agents/:id/tasks
  def task_history
    @agent_id = params[:id]
  end

  private

  def handle_agent_action(action)
    result = Zerobitch::DockerService.public_send(action, params[:id])

    respond_to do |format|
      format.html do
        if result[:success]
          redirect_to zerobitch_path, notice: "#{action.to_s.capitalize} sent to #{params[:id]}."
        else
          redirect_to zerobitch_path, alert: "Failed to #{action} #{params[:id]}: #{result[:error]}"
        end
      end
      format.json do
        render json: {
          success: result[:success],
          id: params[:id],
          action: action,
          error: result[:error]
        }, status: result[:success] ? :ok : :unprocessable_entity
      end
    end
  end

  def fleet_agents
    registry = Zerobitch::AgentRegistry.all
    docker = Zerobitch::DockerService.list_agents.index_by { |row| row[:name] }

    registry.map do |agent|
      docker_row = docker[agent[:id]] || docker[agent[:name].to_s.downcase]
      state = normalize_status(docker_row&.dig(:status).to_s)
      stats = state == "running" ? Zerobitch::DockerService.container_stats(agent[:id]) : {}

      {
        id: agent[:id],
        name: agent[:name],
        emoji: agent[:emoji].presence || "🤖",
        role: agent[:role],
        provider: agent[:provider],
        model: agent[:model],
        status: state,
        status_label: state.capitalize,
        ram_usage: stats[:mem_usage].presence || "—",
        uptime: docker_row&.dig(:created).presence || "—",
        port: agent[:port],
        detail_path: zerobitch_agent_path(agent[:id]),
        task_path: zerobitch_agent_task_path(agent[:id]),
        start_path: start_zerobitch_agent_path(agent[:id]),
        stop_path: stop_zerobitch_agent_path(agent[:id]),
        restart_path: restart_zerobitch_agent_path(agent[:id]),
        delete_path: zerobitch_agent_path(agent[:id]),
        running: state == "running",
        raw_mem_usage: stats[:mem_usage]
      }
    end
  end

  def fleet_summary(agents)
    running = agents.count { |agent| agent[:status] == "running" }
    stopped = agents.count { |agent| agent[:status] == "stopped" }
    restarting = agents.count { |agent| agent[:status] == "restarting" }

    {
      total: agents.size,
      running: running,
      stopped: stopped,
      restarting: restarting,
      total_ram: format("%.1f MiB", agents.sum { |agent| mem_usage_mib(agent[:raw_mem_usage]) })
    }
  end

  def mem_usage_mib(mem_usage)
    text = mem_usage.to_s.split("/").first.to_s.strip
    value = text[/\d+(\.\d+)?/].to_f
    unit = text[/[A-Za-z]+/].to_s.downcase

    case unit
    when "gib", "gb"
      value * 1024
    when "kib", "kb"
      value / 1024
    when "b"
      value / (1024 * 1024)
    else
      value
    end
  end

  def normalize_status(text)
    status_text = text.to_s.downcase
    return "running" if status_text.include?("up")
    return "restarting" if status_text.include?("restarting")

    "stopped"
  end

  def create_agent_params
    params.permit(
      :name,
      :emoji,
      :role,
      :provider,
      :model,
      :api_key_mode,
      :custom_api_key,
      :autonomy,
      :mode,
      :soul_content,
      :agents_content,
      :mem_limit,
      :cpu_limit,
      allowed_commands: []
    )
  end

  def normalize_agent_id(name)
    normalized = name.to_s.downcase.strip.gsub(/[^a-z0-9\-\s]/, "").gsub(/\s+/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
    normalized.presence || "agent-#{SecureRandom.hex(3)}"
  end

  def soul_templates
    [
      {
        id: "minimal-assistant",
        name: "Minimal Assistant",
        description: "Be helpful. Be concise. No fluff.",
        content: "# SOUL\n\nYou are a minimal assistant.\n\n## Core Behavior\n- Be helpful.\n- Be concise.\n- No fluff.\n"
      },
      {
        id: "friendly-companion",
        name: "Friendly Companion",
        description: "Warm, conversational, emoji-forward tone.",
        content: "# SOUL\n\nYou are a friendly companion.\n\n## Voice\n- Warm and conversational\n- Encouraging and empathetic\n- Use emoji naturally\n"
      },
      {
        id: "technical-expert",
        name: "Technical Expert",
        description: "Precise, code-focused, opinionated guidance.",
        content: "# SOUL\n\nYou are a technical expert.\n\n## Style\n- Precise and direct\n- Code-first explanations\n- Strong, reasoned opinions\n"
      },
      {
        id: "creative-partner",
        name: "Creative Partner",
        description: "Brainstormy and imaginative collaborator.",
        content: "# SOUL\n\nYou are a creative partner.\n\n## Approach\n- Explore possibilities\n- Offer imaginative alternatives\n- Build on the user's ideas\n"
      },
      {
        id: "stern-operator",
        name: "Stern Operator",
        description: "Military-efficient with dry humor.",
        content: "# SOUL\n\nYou are a stern operator.\n\n## Behavior\n- Crisp and efficient\n- Prioritize execution and verification\n- Dry humor when useful\n"
      },
      {
        id: "sarcastic-sidekick",
        name: "Sarcastic Sidekick",
        description: "Witty, helpful, with commentary.",
        content: "# SOUL\n\nYou are a sarcastic sidekick.\n\n## Tone\n- Witty and sharp\n- Still practical and helpful\n- Commentary should never block clarity\n"
      }
    ]
  end
end
