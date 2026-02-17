# frozen_string_literal: true

require "digest"
require "open3"
require "shellwords"

class FactoryRunnerV2Job < ApplicationJob
  queue_as :default

  IDLE_WINDOW = 30.minutes

  def perform
    active_loops.find_each do |factory_loop|
      run_loop(factory_loop)
    end
  end

  private

  def active_loops
    if FactoryLoop.column_names.include?("paused")
      FactoryLoop.where(paused: false)
    else
      FactoryLoop.where.not(status: "paused")
    end
  end

  def run_loop(loop)
    return if skip_by_idle_policy?(loop)

    loop_agent = next_loop_agent(loop)
    return unless loop_agent

    agent = loop_agent.factory_agent
    started_at = Time.current
    cycle_log = create_cycle_log!(loop, agent, started_at)
    agent_run = create_agent_run!(loop, agent, cycle_log, started_at)

    stack_info = FactoryStackDetector.call(loop.workspace_path)
    prompt = FactoryPromptCompiler.call(factory_loop: loop, factory_agent: agent, stack_info: stack_info)

    run_result = run_command(loop.workspace_path, command_for(agent, "run_command", stack_info[:test_command]), prompt: prompt)
    verify_result = run_command(loop.workspace_path, command_for(agent, "verify_command", stack_info[:test_command]))

    findings = extract_findings(run_result[:stdout], run_result[:stderr])
    track_patterns!(loop, findings, agent)

    finished_at = Time.current
    duration = (finished_at - started_at).to_i

    if verify_result[:success]
      committed = commit_changes(loop.workspace_path, agent.name)
      status = findings.any? ? "findings" : "clean"
      update_run!(agent_run,
        status: status,
        started_at: started_at,
        finished_at: finished_at,
        duration_seconds: duration,
        findings_count: findings.count,
        commits_count: committed ? 1 : 0,
        confidence_score: findings.any? ? 70 : 95,
        error_message: nil
      )
      cycle_log.update!(
        status: "completed",
        finished_at: finished_at,
        summary: "Factory v2 run completed",
        agent_name: agent.name,
        tests_run: 1,
        tests_passed: 1,
        tests_failed: 0
      )
    else
      rollback_workspace(loop.workspace_path)
      update_run!(agent_run,
        status: "error",
        started_at: started_at,
        finished_at: finished_at,
        duration_seconds: duration,
        findings_count: findings.count,
        commits_count: 0,
        confidence_score: 0,
        error_message: verify_result[:stderr].presence || verify_result[:stdout].presence || "verification failed"
      )
      cycle_log.update!(
        status: "failed",
        finished_at: finished_at,
        summary: "Verification failed",
        agent_name: agent.name,
        tests_run: 1,
        tests_passed: 0,
        tests_failed: 1
      )
    end

    update_last_run_at!(loop_agent, finished_at)
  rescue StandardError => e
    Rails.logger.error("[FactoryRunnerV2Job] loop ##{loop&.id} failed: #{e.class}: #{e.message}")
  end

  def skip_by_idle_policy?(loop)
    idle_policy = loop.respond_to?(:idle_policy) ? loop.idle_policy : nil
    return false unless idle_policy == "pause"

    last_run_time = if loop.respond_to?(:last_cycle_at)
      loop.last_cycle_at
    else
      loop.factory_cycle_logs.maximum(:started_at)
    end

    last_run_time.present? && last_run_time > IDLE_WINDOW.ago
  end

  def next_loop_agent(loop)
    agents = loop.factory_loop_agents.enabled.includes(:factory_agent)
    return nil if agents.blank?

    if FactoryLoopAgent.column_names.include?("run_order")
      agents.min_by { |la| [la[:last_run_at] || Time.at(0), la[:run_order] || 999_999] }
    elsif FactoryLoopAgent.column_names.include?("last_run_at")
      agents.min_by { |la| la[:last_run_at] || Time.at(0) }
    else
      agents.first
    end
  end

  def create_cycle_log!(loop, agent, started_at)
    next_cycle = (loop.factory_cycle_logs.maximum(:cycle_number) || 0) + 1
    loop.factory_cycle_logs.create!(
      cycle_number: next_cycle,
      started_at: started_at,
      status: "running",
      trigger: "idle_agent",
      agent_name: agent.name
    )
  end

  def create_agent_run!(loop, agent, cycle_log, started_at)
    run = {
      factory_loop_id: loop.id,
      factory_agent_id: agent.id,
      factory_cycle_log_id: cycle_log.id,
      started_at: started_at,
      status: "clean",
      findings_count: 0
    }

    FactoryAgentRun.create!(filter_attrs(FactoryAgentRun, run))
  end

  def command_for(agent, attribute, fallback)
    return fallback unless agent.has_attribute?(attribute)

    agent[attribute].presence || fallback
  end

  def run_command(workspace_path, command, prompt: nil)
    env = {}
    env["FACTORY_PROMPT"] = prompt if prompt.present?

    stdout, stderr, status = Open3.capture3(env, "bash", "-lc", command.to_s, chdir: workspace_path.to_s)
    { stdout: stdout.to_s, stderr: stderr.to_s, success: status.success? }
  rescue StandardError => e
    { stdout: "", stderr: e.message, success: false }
  end

  def commit_changes(workspace_path, agent_name)
    dirty = system("bash", "-lc", "cd #{Shellwords.escape(workspace_path.to_s)} && git status --porcelain | grep . >/dev/null")
    return false unless dirty

    system("bash", "-lc", "cd #{Shellwords.escape(workspace_path.to_s)} && git add -A && git commit -m \"[factory] #{agent_name} improvements\"")
  end

  def rollback_workspace(workspace_path)
    system("bash", "-lc", "cd #{Shellwords.escape(workspace_path.to_s)} && git checkout .")
  end

  def extract_findings(*chunks)
    chunks.flat_map do |chunk|
      chunk.to_s.lines.filter_map do |line|
        normalized = line.strip
        next if normalized.blank?
        next unless normalized.downcase.include?("finding") || normalized.start_with?("- ")

        normalized
      end
    end.uniq.first(10)
  end

  def track_patterns!(loop, findings, agent)
    findings.each do |description|
      hash = Digest::SHA256.hexdigest(description.downcase.gsub(/\s+/, " ").strip)
      pattern = FactoryFindingPattern.find_or_initialize_by(factory_loop: loop, pattern_hash: hash)

      pattern.description = description
      pattern.category ||= agent.category

      if pattern.persisted? && pattern.has_attribute?("occurrences")
        pattern.occurrences = pattern.occurrences.to_i + 1
      end

      pattern.save!
    end
  end

  def update_last_run_at!(loop_agent, time)
    return unless FactoryLoopAgent.column_names.include?("last_run_at")

    loop_agent.update!(last_run_at: time)
  end

  def update_run!(agent_run, attrs)
    agent_run.update!(filter_attrs(FactoryAgentRun, attrs))
  end

  def filter_attrs(model_class, attrs)
    allowed = model_class.column_names
    attrs.to_h.stringify_keys.slice(*allowed).symbolize_keys
  end
end
