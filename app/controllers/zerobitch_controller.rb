# frozen_string_literal: true

class ZerobitchController < ApplicationController
  before_action :set_agent, only: %i[
    show_agent start_agent stop_agent restart_agent destroy_agent
    send_task task_history logs memory transfer_memory
    save_soul save_agents save_template
  ]

  def index
    agents = Zerobitch::AgentRegistry.all
    docker = Zerobitch::DockerService
    docker_agents = docker.list_agents

    histories = (Zerobitch::MetricsStore.all_histories(points: 60) rescue {})
    @agents = agents.map do |agent|
      build_agent_snapshot(agent, docker: docker, docker_agents: docker_agents, histories: histories)
    end

    running_agents = @agents.select { |a| a[:status] == "running" }
    running = running_agents.size
    stopped = @agents.size - running
    total_ram_mb = running_agents.filter_map { |a| a[:ram_usage] }
      .sum { |value| Zerobitch::MetricsStore.send(:parse_mem_mb, value) }
    total_ram = total_ram_mb.positive? ? "#{total_ram_mb.round(1)} MiB" : "-"
    ram_values = running_agents.filter_map { |a| a[:ram_percent] }
    avg_ram = ram_values.any? ? "#{(ram_values.sum / ram_values.size).round(1)}%" : "-"

    @summary = {
      total: @agents.size,
      running: running,
      stopped: stopped,
      total_ram: total_ram,
      avg_ram_percent: avg_ram,
      tasks_today: (Zerobitch::MetricsStore.tasks_today rescue 0)
    }

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

  def save_template
    template = params[:template] ||
      params.dig(:agent, :template) ||
      params.dig(:zerobitch, :template) ||
      params.dig(:zerobitch_agent, :template)
    template = template.to_s
    updated = Zerobitch::AgentRegistry.update(@agent[:id], template: template)
    unless updated
      render json: { ok: false, error: "Agent not found" }, status: :not_found
      return
    end

    if request.format.json? || request.xhr?
      render json: { ok: true, template: updated[:template] }
    else
      redirect_to zerobitch_path, notice: "Prompt template updated."
    end
  end

  def metrics
    agents = Zerobitch::AgentRegistry.all
    docker = Zerobitch::DockerService
    docker_agents = docker.list_agents

    # Collect fresh metrics
    Zerobitch::MetricsStore.collect_all rescue nil
    histories = Zerobitch::MetricsStore.all_histories(points: 60)

    total_ram = 0.0
    ram_percents = []
    running = 0
    stopped = 0

    agent_data = agents.map do |agent|
      snapshot = build_agent_snapshot(
        agent,
        docker: docker,
        docker_agents: docker_agents,
        histories: histories,
        include_task_count: true
      )

      if snapshot[:status] == "running"
        running += 1
        if snapshot[:ram_usage].present?
          mem_mb = Zerobitch::MetricsStore.send(:parse_mem_mb, snapshot[:ram_usage])
          total_ram += mem_mb
        end
        ram_percents << snapshot[:ram_percent].to_f if snapshot[:ram_percent].present?
      else
        stopped += 1
      end

      snapshot
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
    action = params[:batch_action].presence || params[:action_type]
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
      batch_action: action,
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
    @provider_models = OpenclawModelsService.provider_models_map
    @providers_for_select = OpenclawModelsService.providers_for_select
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

  def parse_percent(value)
    return nil if value.blank?

    return value.to_f.round(1) if value.is_a?(Numeric)

    m = value.to_s.match(/(\d+(?:\.\d+)?)%/)
    return nil unless m

    m[1].to_f.round(1)
  end

  def build_agent_snapshot(agent, docker:, docker_agents:, histories: {}, include_task_count: false)
    docker_info = docker_agents.find { |d| d[:name] == agent[:container_name] }
    stats = docker_info ? docker.container_stats(agent[:container_name]) : {}
    state_info = docker_info ? docker.container_state(agent[:container_name]) : {}
    status = docker_status_for(docker_info, state_info)
    tasks = (Zerobitch::TaskHistory.all(agent[:id]) rescue [])
    history = histories[agent[:id]] || []
    last_task = tasks.last
    last_activity_value = latest_activity_timestamp(last_task: last_task, history: history, state_info: state_info)
    ram_percent = parse_percent(stats[:mem_percent])
    cron_entries = status == "running" ? fetch_native_cron(agent[:container_name], docker) : []
    cron_entries = cron_entries.presence || []
    cron_display = cron_entries.presence || Array(agent[:cron_schedule].presence)

    agent.merge(
      status: status,
      status_label: status.to_s.capitalize,
      docker_state: state_info[:status] || docker_info&.dig(:state),
      docker_status: docker_info&.dig(:status),
      restart_count: state_info[:restart_count],
      mem_usage: stats[:mem_usage],
      cpu_percent: stats[:cpu_percent],
      ram_usage: stats[:mem_usage] || "—",
      ram_percent: ram_percent,
      ram_limit: stats[:mem_limit] || "—",
      uptime: format_uptime(state_info[:started_at], status),
      last_activity: format_timestamp(last_activity_value) || "Sin actividad registrada",
      template_label: agent[:template].to_s.strip.presence || "sin template",
      cron_entries: cron_entries,
      cron_display: cron_display,
      cron_source: cron_entries.any? ? "native" : (agent[:cron_schedule].present? ? "registry" : nil),
      detail_path: zerobitch_agent_path(agent[:id]),
      provider: agent[:provider] || agent.dig(:config, :provider) || "-",
      model: agent[:model] || agent.dig(:config, :model) || "-",
      task_count: include_task_count ? tasks.size : nil,
      sparkline_mem: history.map { |h| h["mem"] || h[:mem] || 0 },
      sparkline_cpu: history.map { |h| h["cpu"] || h[:cpu] || 0 },
      observability: load_observability_settings(agent)
    )
  end


  def latest_activity_timestamp(last_task:, history:, state_info:)
    task_time = last_task&.dig("timestamp") || last_task&.dig("created_at")
    history_time = Array(history).last&.dig("at") || Array(history).last&.dig(:at)
    heartbeat_time = state_info[:started_at]

    [task_time, history_time, heartbeat_time]
      .compact
      .filter_map { |value| parse_time(value) }
      .max
  end

  def parse_time(value)
    return value if value.is_a?(Time)

    Time.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def docker_status_for(docker_info, state_info)
    state = state_info[:status].to_s.downcase.presence || docker_info&.dig(:state).to_s.downcase.presence
    return "unknown" if state.blank?

    return "running" if state == "running"
    return "paused" if state == "paused"
    return "restarting" if state == "restarting"
    return "dead" if state == "dead"
    return "stopped" if %w[created exited].include?(state)

    "unknown"
  end

  def format_uptime(started_at, status)
    return "—" unless status == "running"
    return "—" if started_at.blank?

    started = Time.parse(started_at.to_s) rescue nil
    return "—" unless started

    seconds = Time.current - started
    human_duration(seconds)
  end

  def human_duration(seconds)
    return "0m" if seconds <= 0

    minutes = (seconds / 60).floor
    hours = minutes / 60
    days = hours / 24
    minutes = minutes % 60
    hours = hours % 24

    parts = []
    parts << "#{days}d" if days.positive?
    parts << "#{hours}h" if hours.positive?
    parts << "#{minutes}m" if minutes.positive? || parts.empty?
    parts.join(" ")
  end

  def format_timestamp(value)
    return nil if value.blank?

    time = value.is_a?(Time) ? value : Time.parse(value.to_s)
    time.strftime("%Y-%m-%d %H:%M")
  rescue ArgumentError, TypeError
    nil
  end

  def fetch_native_cron(container_name, docker)
    result = docker.cron_list(container_name, json: true)
    entries = parse_cron_output(result[:output]) if result[:success]
    return entries if entries.present?

    result = docker.cron_list(container_name, json: false)
    parse_cron_plain(result[:output])
  rescue StandardError
    []
  end

  def parse_cron_output(output)
    parsed = JSON.parse(output.to_s)
    entries = case parsed
              when Array then parsed
              when Hash
                parsed["jobs"] || parsed["crons"] || parsed["entries"] || []
              else
                []
              end
    entries.map { |entry| format_cron_entry(entry) }.compact
  rescue JSON::ParserError
    []
  end

  def parse_cron_plain(output)
    output.to_s.lines.map(&:strip).reject(&:blank?)
  end

  def format_cron_entry(entry)
    return entry if entry.is_a?(String)
    return entry.to_s unless entry.is_a?(Hash)

    name = entry["name"] || entry["id"] || entry["job"] || entry["cron"]
    schedule = entry["schedule"]
    if schedule.is_a?(Hash)
      schedule = schedule["expr"] || schedule["cron"] || schedule["every"] || schedule["at"] || schedule.to_s
    end
    schedule ||= entry["expr"] || entry["cron"]
    enabled = entry.key?("enabled") ? (entry["enabled"] ? "enabled" : "disabled") : nil

    line = [name, schedule].compact.join(": ")
    return line if enabled.blank?

    "#{line} (#{enabled})"
  end

  def load_observability_settings(agent)
    path = resolve_agent_config_path(agent)
    return {} unless path && File.exist?(path)

    parse_observability_section(File.read(path))
  rescue StandardError
    {}
  end

  def resolve_agent_config_path(agent)
    id = agent[:id].to_s
    candidates = [
      Zerobitch::ConfigGenerator::STORAGE_DIR.join("configs", id, "config.toml")
    ]

    fleet_dir = Pathname.new(File.expand_path("~/zeroclaw-fleet/agents"))
    if fleet_dir.exist?
      names = [id]
      container = agent[:container_name].to_s.sub(/\Azeroclaw-/, "")
      names << container if container.present?
      names << id.split("-").first if id.include?("-")
      names << container.split("-").first if container.include?("-")

      names.uniq.each do |name|
        candidates << fleet_dir.join(name, "config.toml")
      end
    end

    candidates.find { |path| path && File.exist?(path) }
  end

  def parse_observability_section(content)
    observability = {}
    in_section = false

    content.to_s.each_line do |line|
      stripped = line.strip
      next if stripped.empty? || stripped.start_with?("#")

      if stripped.match?(/^\[.+\]$/)
        in_section = stripped == "[observability]"
        next
      end

      next unless in_section

      key, value = stripped.split("=", 2)
      next unless value

      value = value.split("#", 2).first.to_s.strip
      value = value.gsub(/\A\"|\"\z/, "")
      observability[key.to_s.strip.to_sym] = value
    end

    observability
  end
end
