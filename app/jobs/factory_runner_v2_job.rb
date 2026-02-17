# frozen_string_literal: true

require "digest"
require "open3"
require "shellwords"

class FactoryRunnerV2Job < ApplicationJob
  queue_as :default

  def perform
    active_loops.find_each do |loop|
      run_loop(loop)
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
    loop_agent = pick_loop_agent(loop)
    return unless loop_agent

    agent = loop_agent.factory_agent
    started_at = Time.current

    cycle_log = create_cycle_log!(loop:, agent:, started_at:)
    agent_run = create_agent_run!(loop:, agent:, cycle_log:, started_at:)

    stack_info = FactoryStackDetector.call(loop.workspace_path)
    prompt = FactoryPromptCompiler.call(factory_loop: loop, factory_agent: agent, stack_info: stack_info)

    run_result = run_improvement(loop:, agent:, prompt:, stack_info:)
    verify_result = verify_workspace(loop:, agent:, stack_info:)

    findings = extract_findings(run_result)
    dedup_findings!(loop:, agent:, findings:)

    finalize_run(
      loop:,
      loop_agent:,
      agent_run:,
      cycle_log:,
      run_result:,
      verify_result:,
      findings:
    )
  rescue StandardError => e
    Rails.logger.error("[FactoryRunnerV2Job] loop ##{loop&.id} failed: #{e.class}: #{e.message}")
  end

  def pick_loop_agent(loop)
    enabled = loop.factory_loop_agents.enabled.includes(:factory_agent)
    return nil if enabled.blank?

    if FactoryLoopAgent.column_names.include?("last_run_at")
      enabled.min_by { |la| [la.last_run_at || Time.at(0), la.id] }
    else
      enabled.min_by do |la|
        last_run = FactoryAgentRun.where(factory_loop_id: loop.id, factory_agent_id: la.factory_agent_id).maximum(:finished_at)
        [last_run || Time.at(0), la.id]
      end
    end
  end

  def create_cycle_log!(loop:, agent:, started_at:)
    attrs = {
      cycle_number: (loop.factory_cycle_logs.maximum(:cycle_number) || 0) + 1,
      status: "running",
      started_at: started_at,
      trigger: "idle_agent",
      agent_name: agent.name
    }

    loop.factory_cycle_logs.create!(filter_attrs(FactoryCycleLog, attrs))
  end

  def create_agent_run!(loop:, agent:, cycle_log:, started_at:)
    attrs = {
      factory_loop_id: loop.id,
      factory_agent_id: agent.id,
      factory_cycle_log_id: cycle_log.id,
      status: "clean",
      started_at: started_at,
      findings_count: 0
    }

    FactoryAgentRun.create!(filter_attrs(FactoryAgentRun, attrs))
  end

  def run_improvement(loop:, agent:, prompt:, stack_info:)
    default_command = "echo \"$FACTORY_PROMPT\" > /dev/null"
    run_command = command_for(agent, :run_command, default_command)

    shell_out(loop.workspace_path, run_command, env: {
      "FACTORY_PROMPT" => prompt,
      "FACTORY_TEST_COMMAND" => stack_info[:test_command],
      "FACTORY_SYNTAX_CHECK" => stack_info[:syntax_check]
    })
  end

  def verify_workspace(loop:, agent:, stack_info:)
    syntax_command = stack_info[:syntax_check].presence || "true"
    tests_command = command_for(agent, :verify_command, stack_info[:test_command].presence || "true")

    syntax = shell_out(loop.workspace_path, syntax_command)
    return syntax.merge(step: :syntax) unless syntax[:success]

    tests = shell_out(loop.workspace_path, tests_command)
    tests.merge(step: :tests)
  end

  def finalize_run(loop:, loop_agent:, agent_run:, cycle_log:, run_result:, verify_result:, findings:)
    finished_at = Time.current

    if verify_result[:success]
      committed = commit_or_skip(loop.workspace_path, cycle_log)
      update_agent_run!(agent_run, {
        status: findings.any? ? "findings" : "clean",
        finished_at: finished_at,
        findings_count: findings.count,
        items_generated: findings.count,
        commit_sha: committed,
        findings: findings
      })

      cycle_log.update!(filter_attrs(FactoryCycleLog, {
        status: "completed",
        finished_at: finished_at,
        summary: run_result[:stdout].to_s.lines.last(3).join.strip.presence || "Factory v2 run completed",
        tests_run: 1,
        tests_passed: 1,
        tests_failed: 0
      }))
    else
      revert_workspace(loop.workspace_path)
      update_agent_run!(agent_run, {
        status: "error",
        finished_at: finished_at,
        findings_count: findings.count,
        items_generated: 0,
        findings: findings
      })

      cycle_log.update!(filter_attrs(FactoryCycleLog, {
        status: "failed",
        finished_at: finished_at,
        summary: "Verification failed (#{verify_result[:step]}): #{verify_result[:stderr].presence || verify_result[:stdout].presence || 'unknown'}",
        tests_run: 1,
        tests_passed: 0,
        tests_failed: 1
      }))
    end

    update_loop_agent_last_run_at!(loop_agent, finished_at)
  end

  def command_for(agent, attr, fallback)
    return fallback unless agent.has_attribute?(attr)

    agent.public_send(attr).presence || fallback
  end

  def shell_out(workspace_path, command, env: {})
    stdout, stderr, status = Open3.capture3(env, "bash", "-lc", command.to_s, chdir: workspace_path.to_s)
    { success: status.success?, stdout: stdout.to_s, stderr: stderr.to_s, command: command }
  rescue StandardError => e
    { success: false, stdout: "", stderr: e.message, command: command }
  end

  def commit_or_skip(workspace_path, cycle_log)
    dirty = system("bash", "-lc", "cd #{Shellwords.escape(workspace_path)} && git status --porcelain | grep -q .")
    return nil unless dirty

    message = "[factory-v2] cycle ##{cycle_log.id} automated improvement"
    committed = system("bash", "-lc", "cd #{Shellwords.escape(workspace_path)} && git add -A && git commit -m #{Shellwords.escape(message)} >/dev/null")
    return nil unless committed

    `bash -lc "cd #{Shellwords.escape(workspace_path)} && git rev-parse HEAD"`.strip
  end

  def revert_workspace(workspace_path)
    system("bash", "-lc", "cd #{Shellwords.escape(workspace_path)} && git reset --hard HEAD >/dev/null && git clean -fd >/dev/null")
  end

  def extract_findings(run_result)
    text = [run_result[:stdout], run_result[:stderr]].join("\n")
    text.lines.map(&:strip).filter_map do |line|
      next if line.blank?
      next unless line.start_with?("FINDING:") || line.start_with?("- [finding]")

      line.sub(/^FINDING:\s*/i, "").sub(/^- \[finding\]\s*/i, "")
    end.uniq.first(25)
  end

  def dedup_findings!(loop:, agent:, findings:)
    findings.each do |description|
      normalized = description.downcase.gsub(/\s+/, " ").strip
      hash = Digest::SHA256.hexdigest(normalized)

      pattern = FactoryFindingPattern.find_or_initialize_by(factory_loop: loop, pattern_hash: hash)
      attrs = {
        category: pattern.category.presence || agent.category,
        description: description
      }

      if pattern.new_record?
        attrs[:first_seen_at] = Time.current if pattern.has_attribute?(:first_seen_at)
        attrs[:occurrences] = 1 if pattern.has_attribute?(:occurrences)
      else
        attrs[:occurrences] = pattern.occurrences.to_i + 1 if pattern.has_attribute?(:occurrences)
      end

      attrs[:last_seen_at] = Time.current if pattern.has_attribute?(:last_seen_at)
      pattern.update!(filter_attrs(FactoryFindingPattern, attrs))
    end
  end

  def update_loop_agent_last_run_at!(loop_agent, timestamp)
    return unless loop_agent.has_attribute?(:last_run_at)

    loop_agent.update!(last_run_at: timestamp)
  end

  def update_agent_run!(agent_run, attrs)
    base = { finished_at: Time.current }
    filtered = filter_attrs(FactoryAgentRun, base.merge(attrs))

    if filtered.key?(:started_at) && filtered[:started_at].blank?
      filtered.delete(:started_at)
    end

    agent_run.update!(filtered)
  end

  def filter_attrs(model_class, attrs)
    attrs.stringify_keys.slice(*model_class.column_names).symbolize_keys
  end
end
