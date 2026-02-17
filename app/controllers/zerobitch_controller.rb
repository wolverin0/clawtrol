# frozen_string_literal: true

class ZerobitchController < ApplicationController
  before_action :set_agent, only: %i[
    show_agent start_agent stop_agent restart_agent destroy_agent
    send_task task_history logs memory transfer_memory
    save_soul save_agents
  ]

  def index
    agents = Zerobitch::AgentRegistry.all
    docker = Zerobitch::DockerService
    docker_agents = docker.list_agents

    @agents = agents.map do |agent|
      docker_info = docker_agents.find { |d| d[:name] == agent[:container_name] }
      stats = docker_info ? docker.container_stats(agent[:container_name]) : {}
      status = if docker_info
                 docker_info[:state] == "running" ? "running" : "stopped"
               else
                 "stopped"
               end
      agent.merge(
        status: status,
        docker_state: docker_info&.dig(:state),
        docker_status: docker_info&.dig(:status),
        mem_usage: stats[:mem_usage],
        cpu_percent: stats[:cpu_percent],
        provider: agent[:provider] || agent.dig(:config, :provider) || "-",
        model: agent[:model] || agent.dig(:config, :model) || "-"
      )
    end

    running = @agents.count { |a| a[:status] == "running" }
    stopped = @agents.count { |a| a[:status] != "running" }
    total_ram = @agents.filter_map { |a| a[:mem_usage] }.join(", ").presence || "-"
    ram_values = @agents.filter_map { |a| a[:mem_usage]&.match(/(\d+\.?\d*)%/)&.[](1)&.to_f }
    avg_ram = ram_values.any? ? "#{(ram_values.sum / ram_values.size).round(1)}%" : "-"

    @summary = {
      total: @agents.size,
      running: running,
      stopped: stopped,
      total_ram: total_ram,
      avg_ram_percent: avg_ram,
      tasks_today: (Zerobitch::MetricsStore.tasks_today rescue 0)
    }

    # Attach sparkline data
    histories = (Zerobitch::MetricsStore.all_histories(points: 60) rescue {})
    @agents.each do |agent|
      h = histories[agent[:id]] || []
      agent[:sparkline_mem] = h.map { |p| p["mem"] || p[:mem] || 0 }
    end
  end

  def new_agent
    @templates = Zerobitch::FleetTemplates.all
    set_spawn_defaults
  end

  def create_agent
    attrs = agent_params
    agent = Zerobitch::AgentRegistry.create(attrs)

    # Generate config and workspace
    config_path = Zerobitch::ConfigGenerator.generate_config(agent[:id], attrs)
    Zerobitch::ConfigGenerator.generate_workspace(
      agent[:id],
      soul_content: attrs[:soul_md] || "",
      agents_content: attrs[:agents_md] || ""
    )

    # Start container
    docker = Zerobitch::DockerService
    docker.run(
      name: agent[:container_name],
      config_path: config_path,
      workspace_path: File.join(Zerobitch::ConfigGenerator::STORAGE_DIR, "workspaces", agent[:id]),
      port: agent[:port],
      mem_limit: attrs[:mem_limit] || "32m",
      cpu_limit: attrs[:cpu_limit] || "0.5",
      command: attrs[:mode] || "daemon"
    )

    redirect_to zerobitch_path, notice: "Agent #{agent[:name]} created and started."
  rescue => e
    flash.now[:alert] = "Failed to create agent: #{e.message}"
    @templates = Zerobitch::FleetTemplates.all
    set_spawn_defaults
    render :new_agent, status: :unprocessable_entity
  end

  def show_agent
    docker = Zerobitch::DockerService
    docker_agents = docker.list_agents
    docker_info = docker_agents.find { |d| d[:name] == @agent[:container_name] }
    @stats = docker_info ? docker.container_stats(@agent[:container_name]) : {}
    @agent = @agent.merge(
      status: docker_info&.dig(:state) == "running" ? "running" : "stopped",
      docker_state: docker_info&.dig(:state),
      docker_status: docker_info&.dig(:status),
      provider: @agent[:provider] || @agent.dig(:config, :provider) || "-",
      model: @agent[:model] || @agent.dig(:config, :model) || "-"
    )

    # Load config for display
    config_path = File.join(Zerobitch::ConfigGenerator::STORAGE_DIR, "configs", @agent[:id], "config.toml")
    @config_content = File.exist?(config_path) ? File.read(config_path) : "No config found."

    # Load SOUL.md
    soul_path = File.join(Zerobitch::ConfigGenerator::STORAGE_DIR, "workspaces", @agent[:id], "SOUL.md")
    @soul_content = File.exist?(soul_path) ? File.read(soul_path) : ""

    # Load AGENTS.md
    agents_path = File.join(Zerobitch::ConfigGenerator::STORAGE_DIR, "workspaces", @agent[:id], "AGENTS.md")
    @agents_content = File.exist?(agents_path) ? File.read(agents_path) : ""
  end

  def start_agent
    Zerobitch::DockerService.start(@agent[:container_name])
    redirect_back fallback_location: zerobitch_agent_path(@agent[:id]), notice: "Agent started."
  rescue => e
    redirect_back fallback_location: zerobitch_agent_path(@agent[:id]), alert: "Start failed: #{e.message}"
  end

  def stop_agent
    Zerobitch::DockerService.stop(@agent[:container_name])
    redirect_back fallback_location: zerobitch_agent_path(@agent[:id]), notice: "Agent stopped."
  rescue => e
    redirect_back fallback_location: zerobitch_agent_path(@agent[:id]), alert: "Stop failed: #{e.message}"
  end

  def restart_agent
    Zerobitch::DockerService.restart(@agent[:container_name])
    redirect_back fallback_location: zerobitch_agent_path(@agent[:id]), notice: "Agent restarted."
  rescue => e
    redirect_back fallback_location: zerobitch_agent_path(@agent[:id]), alert: "Restart failed: #{e.message}"
  end

  def destroy_agent
    docker = Zerobitch::DockerService
    begin
      docker.stop(@agent[:container_name])
      docker.remove(@agent[:container_name])
    rescue => e
      Rails.logger.warn("[ZeroBitch] Container cleanup failed: #{e.message}")
    end
    Zerobitch::AgentRegistry.destroy(@agent[:id])
    redirect_to zerobitch_path, notice: "Agent #{@agent[:name]} deleted."
  end

  def send_task
    prompt = params[:prompt].to_s.strip
    return head(:unprocessable_entity) if prompt.blank?

    timeout = (@agent[:task_timeout].presence || 120).to_i
    docker = Zerobitch::DockerService
    result = docker.exec_task(@agent[:container_name], prompt, timeout: timeout)

    success = result[:exit_code]&.zero?
    Zerobitch::TaskHistory.log(
      @agent[:id],
      prompt: prompt,
      result: result[:output],
      duration_ms: result[:duration_ms],
      success: success
    )

    if request.format.json? || request.xhr?
      render json: {
        ok: true,
        task: {
          result: result[:output],
          exit_code: result[:exit_code],
          duration_ms: result[:duration_ms]
        }
      }
    else
      redirect_to zerobitch_agent_path(@agent[:id]), notice: "Task sent."
    end
  rescue => e
    Zerobitch::TaskHistory.log(@agent[:id], prompt: prompt, result: e.message, duration_ms: 0, success: false)
    if request.format.json? || request.xhr?
      render json: { ok: false, error: e.message }, status: :internal_server_error
    else
      redirect_to zerobitch_agent_path(@agent[:id]), alert: "Task failed: #{e.message}"
    end
  end

  def task_history
    @agent_id = params[:id]
    @tasks = Zerobitch::TaskHistory.all(@agent_id)

    if request.format.json? || request.xhr?
      render json: { tasks: @tasks }
    end
  end

  def logs
    @agent_id = params[:id]
    docker = Zerobitch::DockerService
    tail = (params[:tail] || 200).to_i
    result = docker.logs(@agent[:container_name], tail: tail)
    @log_output = [result[:output], result[:error]].reject(&:empty?).join("\n")

    if request.format.json? || request.xhr?
      render json: { output: @log_output }
    end
  end

  def memory
    @query = params[:q].to_s.strip
    if @query.present?
      @entries = Zerobitch::MemoryBrowser.search(@agent[:id], @query)
    else
      @entries = Zerobitch::MemoryBrowser.entries(@agent[:id])
    end
  end

  def transfer_memory
    target_id = params[:target_agent_id]
    target = Zerobitch::AgentRegistry.find(target_id)
    unless target
      redirect_to zerobitch_agent_memory_path(@agent[:id]), alert: "Target agent not found."
      return
    end

    result = Zerobitch::MemoryBrowser.transfer(@agent[:id], target_id)
    if result[:transferred].to_i > 0
      redirect_to zerobitch_agent_memory_path(@agent[:id]), notice: "✅ Transferred #{result[:transferred]} entries to #{target[:emoji]} #{target[:name]}."
    else
      redirect_to zerobitch_agent_memory_path(@agent[:id]), alert: "No entries to transfer."
    end
  end

  def save_soul
    soul_path = File.join(Zerobitch::ConfigGenerator::STORAGE_DIR, "workspaces", @agent[:id], "SOUL.md")
    FileUtils.mkdir_p(File.dirname(soul_path))
    File.write(soul_path, params[:content].to_s)
    if request.format.json? || request.xhr?
      render json: { ok: true }
    else
      redirect_to zerobitch_agent_path(@agent[:id]), notice: "SOUL.md updated."
    end
  end

  def save_agents
    agents_path = File.join(Zerobitch::ConfigGenerator::STORAGE_DIR, "workspaces", @agent[:id], "AGENTS.md")
    FileUtils.mkdir_p(File.dirname(agents_path))
    File.write(agents_path, params[:content].to_s)
    if request.format.json? || request.xhr?
      render json: { ok: true }
    else
      redirect_to zerobitch_agent_path(@agent[:id]), notice: "AGENTS.md updated."
    end
  end

    def metrics
    agents = Zerobitch::AgentRegistry.all
    docker = Zerobitch::DockerService

    # Collect fresh metrics
    Zerobitch::MetricsStore.collect_all rescue nil
    histories = Zerobitch::MetricsStore.all_histories(points: 60)

    total_ram = 0.0
    ram_percents = []
    running = 0
    stopped = 0

    agent_data = agents.map do |agent|
      stats = docker.container_stats(agent[:container_name]) rescue {}
      status = docker.status(agent[:container_name]) rescue "stopped"

      if status == "running"
        running += 1
        mem_mb = Zerobitch::MetricsStore.send(:parse_mem_mb, stats[:mem_usage])
        total_ram += mem_mb
        ram_percents << Zerobitch::MetricsStore.send(:parse_percent, stats[:cpu_percent])
      else
        stopped += 1
      end

      task_count = (Zerobitch::TaskHistory.all(agent[:id]) || []).size
      history = histories[agent[:id]] || []

      agent.merge(
        status: status,
        status_label: status&.capitalize,
        ram_usage: stats[:mem_usage] || "—",
        ram_percent: Zerobitch::MetricsStore.send(:parse_percent, stats[:cpu_percent]),
        ram_limit: stats[:mem_limit],
        detail_path: zerobitch_agent_path(agent[:id]),
        sparkline_mem: history.map { |h| h["mem"] || h[:mem] },
        sparkline_cpu: history.map { |h| h["cpu"] || h[:cpu] },
        task_count: task_count
      )
    end

    avg_ram = ram_percents.any? ? (ram_percents.sum / ram_percents.size).round(1) : 0

    render json: {
      summary: {
        total: agents.size,
        running: running,
        stopped: stopped,
        total_ram: "#{total_ram.round(1)} MiB",
        avg_ram_percent: "#{avg_ram}%",
        tasks_today: Zerobitch::MetricsStore.tasks_today
      },
      agents: agent_data
    }
  end

  def batch_action
    action = params[:action].presence || params[:action_type]
    agent_ids = Array(params[:agent_ids])
    prompt = params[:prompt].to_s.strip
    results = []
    docker = Zerobitch::DockerService

    agent_ids.each do |id|
      agent = Zerobitch::AgentRegistry.find(id)
      next unless agent
      begin
        case action
        when "start_all", "start"
          docker.start(agent[:container_name])
          results << { id: id, success: true }
        when "stop_all", "stop"
          docker.stop(agent[:container_name])
          results << { id: id, success: true }
        when "delete_all", "delete"
          docker.stop(agent[:container_name]) rescue nil
          docker.remove(agent[:container_name]) rescue nil
          Zerobitch::AgentRegistry.destroy(id)
          results << { id: id, success: true }
        when "broadcast"
          raise "Prompt is required for broadcast" if prompt.blank?
          result = docker.exec_task(agent[:container_name], prompt, timeout: 120)
          Zerobitch::TaskHistory.log(id, prompt: prompt, result: result[:output], duration_ms: result[:duration_ms], success: result[:exit_code]&.zero?)
          results << { id: id, success: result[:exit_code]&.zero?, output: result[:output]&.truncate(500), duration_ms: result[:duration_ms] }
        else
          results << { id: id, success: false, error: "Unknown action: #{action}" }
        end
      rescue => e
        results << { id: id, success: false, error: e.message }
      end
    end

    ok_count = results.count { |r| r[:success] }
    payload = {
      action: action,
      total: results.size,
      ok: ok_count,
      failed: results.size - ok_count,
      results: results
    }

    if request.format.json? || request.xhr?
      render json: payload
    else
      redirect_to zerobitch_path, notice: "Batch action completed."
    end
  end

  def clear_task_history
    Zerobitch::TaskHistory.clear(params[:id])
    redirect_to zerobitch_agent_tasks_path(params[:id]), notice: "Task history cleared."
  end

  # Rules
  def rules
    @rules = Zerobitch::AutoScaler.rules
  end

  def new_rule; end

  def create_rule
    Zerobitch::AutoScaler.add_rule(
      name: params[:name],
      condition: { type: params[:condition_type], threshold: params[:condition_threshold] },
      action: { type: params[:action_type], template_id: params[:template_id] },
      enabled: params[:enabled] != "0"
    )
    redirect_to zerobitch_rules_path, notice: "Rule created."
  end

  def toggle_rule
    rules = Zerobitch::AutoScaler.rules
    rule = rules.find { |r| r["id"] == params[:rule_id] }
    if rule
      rule["enabled"] = !rule["enabled"]
      rules_path = Zerobitch::AutoScaler::RULES_PATH
      FileUtils.mkdir_p(rules_path.dirname)
      File.write(rules_path, JSON.pretty_generate(rules))
    end
    redirect_to zerobitch_rules_path, notice: rule ? "Rule #{rule['enabled'] ? 'enabled' : 'disabled'}." : "Rule not found."
  end

  def destroy_rule
    rules = Zerobitch::AutoScaler.rules
    rules.reject! { |r| r["id"] == params[:rule_id] }
    # Write back (auto_scaler doesn't expose delete, write directly)
    rules_path = File.join(Rails.root, "storage", "zerobitch", "rules.json")
    File.write(rules_path, JSON.pretty_generate(rules))
    redirect_to zerobitch_rules_path, notice: "Rule deleted."
  end

  def evaluate_rules
    @results = Zerobitch::AutoScaler.evaluate_rules
    triggered = @results[:triggered] || 0
    errors = @results[:errors] || []
    msg = "Evaluated: #{triggered} triggered"
    msg += ", #{errors.size} errors" if errors.any?
    redirect_to zerobitch_rules_path, notice: msg
  end

  # Assign task from ClawTrol
    def assign_task
    agent_id = params[:agent_id]
    task_id = params[:task_id]
    agent = Zerobitch::AgentRegistry.find(agent_id)
    return head(:not_found) unless agent

    task = fetch_clawtrol_task(task_id)
    return head(:not_found) unless task

    prompt = task["description"].presence || task["title"] || "No description"
    result = Zerobitch::DockerService.exec_task(agent[:container_name], prompt, timeout: 120)
    success = result[:exit_code]&.zero?

    Zerobitch::TaskHistory.log(
      agent_id,
      prompt: prompt,
      result: result[:output],
      duration_ms: result[:duration_ms],
      success: success
    )

    # Fire outcome hooks back to ClawTrol
    fire_outcome_hook(task_id, agent_id, result, success)

    if request.format.json? || request.xhr?
      render json: { ok: true, task: { result: result[:output], exit_code: result[:exit_code], duration_ms: result[:duration_ms] } }
    else
      notice = success ? "✅ Task dispatched to #{agent[:name]} (#{result[:duration_ms]}ms)" : "⚠️ Task sent to #{agent[:name]} but exited #{result[:exit_code]}"
      redirect_back fallback_location: zerobitch_path, notice: notice
    end
  rescue => e
    Zerobitch::TaskHistory.log(agent_id, prompt: prompt.to_s, result: e.message, duration_ms: 0, success: false) rescue nil
    if request.format.json? || request.xhr?
      render json: { ok: false, error: e.message }, status: :internal_server_error
    else
      redirect_back fallback_location: zerobitch_path, alert: "Assignment failed: #{e.message}"
    end
  end

  private

  def set_spawn_defaults
    @default_emoji = "🤖"
    @allowed_commands = %w[curl cat grep ls find jq docker df free ps ping git awk]
    @provider_models = {
      "openrouter" => %w[meta-llama/llama-3.3-70b-instruct:free google/gemini-2.0-flash-exp:free anthropic/claude-3.5-sonnet],
      "groq" => %w[llama-3.3-70b-versatile llama-4-scout-17b-16e-instruct],
      "cerebras" => %w[llama-3.3-70b qwen-3-235b-a22b-instruct],
      "mistral" => %w[mistral-small-latest mistral-medium-latest],
      "ollama" => %w[llama3.2:3b qwen2.5:7b]
    }
    @soul_templates = Zerobitch::FleetTemplates.all.map do |t|
      { id: t[:id], name: "#{t[:emoji]} #{t[:name]}", content: t[:soul_content] }
    end
  end

  def set_agent
    @agent = Zerobitch::AgentRegistry.find(params[:id])
    unless @agent
      redirect_to zerobitch_path, alert: "Agent not found."
    end
  end

  def agent_params
    params.permit(
      :name, :emoji, :role, :provider, :model, :api_key,
      :autonomy, :soul_md, :agents_md, :mode, :port,
      :mem_limit, :cpu_limit, :task_timeout, :template_id,
      allowed_commands: []
    ).to_h.symbolize_keys
  end

  def fire_outcome_hook(task_id, agent_id, result, success)
    token = ENV.fetch("CLAWTROL_HOOKS_TOKEN", nil)
    return unless token

    run_id = "zeroclaw-#{agent_id}-#{Time.current.to_i}"
    base = "http://localhost:4001/api/v1/hooks"

    # task_outcome
    post_hook("#{base}/task_outcome", token, {
      version: 1, task_id: task_id.to_i, run_id: run_id,
      outcome: success ? "success" : "failure",
      summary: result[:output].to_s.truncate(500),
      needs_follow_up: false
    })

    # agent_complete
    post_hook("#{base}/agent_complete", token, {
      version: 1, task_id: task_id.to_i, run_id: run_id,
      output: result[:output].to_s.truncate(2000),
      output_files: []
    })
  rescue => e
    Rails.logger.warn("[ZeroBitch] Failed to fire outcome hooks for task #{task_id}: #{e.message}")
  end

  def post_hook(url, token, payload)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["X-Hook-Token"] = token
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(payload)
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  end

  def fetch_clawtrol_task(task_id)
    token = ENV.fetch("CLAWTROL_API_TOKEN", nil)
    return nil unless token
    uri = URI("http://localhost:4001/api/v1/tasks/#{task_id}")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{token}"
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    return nil unless res.code == "200"
    JSON.parse(res.body)
  rescue
    nil
  end
end
