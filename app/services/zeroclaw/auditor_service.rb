# frozen_string_literal: true

require "uri"

module Zeroclaw
  class AuditorService
    START_MARKER = "## Auditor Verdict"
    END_MARKER = "## Auditor End"

    PIPELINE_TYPE_MAP = {
      "feature" => "coding",
      "bug-fix" => "coding",
      "quick-fix" => "infra",
      "research" => "research"
    }.freeze

    Result = Struct.new(
      :verdict,
      :score,
      :summary,
      :checks,
      :required_fixes,
      :proof,
      :confidence,
      :task_type,
      keyword_init: true
    )

    def initialize(task, trigger: "auto")
      @task = task
      @trigger = trigger
    end

    def call
      task_type = detect_task_type
      checklist = ChecklistLoader.load(task_type)
      signals = build_signals

      checks = build_checks(task_type, checklist, signals)
      score = checks.sum { |check| check[:status] == "pass" ? check[:weight].to_i : 0 }
      critical_missing = missing_required_signals(checklist["critical_signals"], signals)
      required_fixes = build_required_fixes(checklist, signals)

      verdict = compute_verdict(score:, critical_missing:, required_fixes:)
      summary = build_summary(verdict:, score:, checks:, critical_missing:)
      proof = build_proof
      confidence = ((checks.count { |check| check[:status] == "pass" }.to_f / [checks.size, 1].max) * 100.0).round(1)

      result = Result.new(
        verdict: verdict,
        score: score,
        summary: summary,
        checks: checks,
        required_fixes: required_fixes,
        proof: proof,
        confidence: confidence,
        task_type: task_type
      )

      apply!(result)
      result.to_h
    end

    private

    def apply!(result)
      state = (@task.state_data.is_a?(Hash) ? @task.state_data.deep_dup : {})
      auditor_state = state.fetch("auditor", {})
      rework_count = auditor_state.fetch("rework_count", 0).to_i

      if result.verdict == "FAIL_REWORK"
        rework_count += 1
      end

      auditor_payload = {
        "verdict" => result.verdict,
        "score" => result.score,
        "summary" => result.summary,
        "checks" => result.checks,
        "required_fixes" => result.required_fixes,
        "proof" => result.proof,
        "confidence" => result.confidence,
        "task_type" => result.task_type,
        "trigger" => @trigger,
        "model" => AuditorConfig.llm_model,
        "mode" => AuditorConfig.mode,
        "completed_at" => Time.current.iso8601
      }

      state["auditor"] = {
        "last" => auditor_payload,
        "rework_count" => rework_count,
        "history" => Array(auditor_state["history"]).last(14) + [auditor_payload.slice("verdict", "score", "task_type", "completed_at")]
      }

      config = (@task.review_config.is_a?(Hash) ? @task.review_config.deep_dup : {})
      config["auditor"] = {
        "enabled" => AuditorConfig.enabled?,
        "mode" => AuditorConfig.mode,
        "model" => AuditorConfig.llm_model,
        "max_rework_loops" => AuditorConfig.max_rework_loops,
        "trigger" => @trigger,
        "task_type" => result.task_type
      }

      review_result = (@task.review_result.is_a?(Hash) ? @task.review_result.deep_dup : {})
      review_result["auditor"] = auditor_payload

      updates = {
        review_type: "auditor",
        review_status: (result.verdict == "PASS" ? "passed" : "failed"),
        review_config: config,
        review_result: review_result,
        state_data: state,
        description: with_auditor_section(@task.description, result)
      }

      case result.verdict
      when "PASS"
        updates[:status] = "done" if AuditorConfig.auto_done?
      when "FAIL_REWORK"
        updates[:status] = "in_progress"
        updates[:agent_claimed_at] = nil
      when "NEEDS_HUMAN"
        updates[:status] = "in_review"
      end

      @task.update!(updates)

      Notification.create_for_review(@task, passed: result.verdict == "PASS")
      if result.verdict == "NEEDS_HUMAN"
        Notification.create_deduped!(
          user: @task.user,
          task: @task,
          event_type: "job_alert",
          message: "Auditor requires human decision on #{@task.name.truncate(60)}"
        )
      end
    end

    def detect_task_type
      tags = Array(@task.tags).map { |tag| tag.to_s.downcase }
      return tags.find { |tag| AuditorConfig.auditable_tags.include?(tag) } if tags.any? { |tag| AuditorConfig.auditable_tags.include?(tag) }

      pipeline_type = @task.pipeline_type.to_s.downcase
      return PIPELINE_TYPE_MAP[pipeline_type] if PIPELINE_TYPE_MAP.key?(pipeline_type)

      "default"
    end

    def build_signals
      output = auditor_target_text
      output_files = Array(@task.output_files).map(&:to_s).reject(&:blank?)
      links = extract_links(output)

      {
        "acceptance_criteria_present" => acceptance_criteria.any?,
        "executor_output_present" => output.present?,
        "output_files_present" => output_files.any?,
        "output_files_accessible" => output_files.any? && output_files_accessible?(output_files),
        "source_links_present" => links.any?,
        "validation_signal_present" => validation_signal_present?,
        "rollback_plan_present" => rollback_present?(output),
        "summary_present" => summary_present?(output),
        "no_forbidden_claims" => !output.match?(/\b(TODO|TBD|fix\s+later|placeholder)\b/i)
      }
    end

    def build_checks(task_type, checklist, signals)
      weights = checklist.fetch("weights", {})

      dod_signals = %w[acceptance_criteria_present executor_output_present]
      evidence_signals = case task_type
      when "coding"
        %w[output_files_present output_files_accessible validation_signal_present]
      when "research"
        %w[source_links_present summary_present]
      when "infra"
        %w[output_files_present output_files_accessible rollback_plan_present]
      when "report"
        %w[output_files_present source_links_present]
      else
        %w[output_files_present output_files_accessible summary_present]
      end

      [
        check_row("DoD completeness", weights.fetch("dod", 40), dod_signals, signals),
        check_row("Evidence quality", weights.fetch("evidence", 30), evidence_signals, signals),
        check_row("Policy compliance", weights.fetch("policy", 20), %w[no_forbidden_claims], signals),
        check_row("Handoff quality", weights.fetch("handoff", 10), %w[summary_present], signals)
      ]
    end

    def check_row(name, weight, required_signals, signals)
      missing = missing_required_signals(required_signals, signals)
      {
        name: name,
        weight: weight,
        status: missing.empty? ? "pass" : "fail",
        details: missing.empty? ? "All required signals present" : "Missing: #{missing.join(', ')}"
      }
    end

    def build_required_fixes(checklist, signals)
      fixes = []
      templates = checklist.fetch("fix_instructions", {})
      required_signals = Array(checklist["required_signals"]).map(&:to_s)

      required_signals.each do |signal|
        next if signals[signal]

        template = templates[signal] || {}
        fixes << {
          id: "F#{fixes.size + 1}",
          severity: (template["severity"] || "major"),
          instruction: (template["instruction"] || "Provide missing evidence for #{signal}"),
          expected_proof: (template["expected_proof"] || "Attach verifiable artifact")
        }
      end

      fixes.first(5)
    end

    def compute_verdict(score:, critical_missing:, required_fixes:)
      if score >= 85 && critical_missing.empty? && required_fixes.empty?
        return "PASS"
      end

      current_reworks = current_rework_count
      if score < 50 || (required_fixes.any? && current_reworks >= AuditorConfig.max_rework_loops)
        return "NEEDS_HUMAN"
      end

      "FAIL_REWORK"
    end

    def build_summary(verdict:, score:, checks:, critical_missing:)
      failed = checks.count { |check| check[:status] == "fail" }
      base = "Verdict #{verdict} (score #{score}/100, failed checks #{failed})"
      return base if critical_missing.empty?

      "#{base}. Critical missing: #{critical_missing.join(', ')}"
    end

    def build_proof
      {
        files_checked: Array(@task.output_files).map(&:to_s).reject(&:blank?),
        links_verified: extract_links(auditor_target_text),
        commands_run: ["rule_based_signals_v1"]
      }
    end

    def with_auditor_section(description, result)
      base = description.to_s
      base = base.sub(/\n?#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}\n?/m, "\n")

      lines = []
      lines << START_MARKER
      lines << "Verdict: #{result.verdict}"
      lines << "Score: #{result.score}/100"
      lines << "Summary: #{result.summary}"
      lines << ""
      lines << "Checks:"
      result.checks.each do |check|
        lines << "- #{check[:name]}: #{check[:status]} (#{check[:details]})"
      end
      if result.required_fixes.any?
        lines << ""
        lines << "Required Fixes:"
        result.required_fixes.each do |fix|
          lines << "- [#{fix[:severity]}] #{fix[:instruction]} (Proof: #{fix[:expected_proof]})"
        end
      end
      lines << END_MARKER

      [base.strip, lines.join("\n")].reject(&:blank?).join("\n\n") + "\n"
    end

    def acceptance_criteria
      contract = (@task.review_config || {})["swarm_contract"]
      criteria = contract.is_a?(Hash) ? contract["acceptance_criteria"] : nil
      Array(criteria).map(&:to_s).map(&:strip).reject(&:blank?)
    rescue StandardError
      []
    end

    def validation_signal_present?
      return true if @task.validation_status.to_s == "passed"

      output = auditor_target_text
      return true if output.match?(/\b(test|tests|lint|validation|passed|green)\b/i)

      false
    end

    def rollback_present?(text)
      text.to_s.match?(/\brollback\b|\broll\s*back\b|\brevert\b/i)
    end

    def summary_present?(text)
      trimmed = text.to_s.strip
      return false if trimmed.blank?

      line_count = trimmed.lines.count
      line_count >= 2
    end

    def auditor_target_text
      description = @task.description.to_s
      if @task.respond_to?(:agent_output_text) && @task.agent_output_text.present?
        @task.agent_output_text
      else
        description
      end
    end

    def output_files_accessible?(paths)
      paths.any? do |path|
        next true if path.start_with?("http://", "https://")

        absolute = if path.start_with?("/")
          path
        else
          Rails.root.join(path).to_s
        end

        File.exist?(absolute)
      rescue StandardError
        false
      end
    end

    def extract_links(text)
      text.to_s.scan(%r{https?://[^\s\)\]>]+}).uniq
    end

    def current_rework_count
      state = @task.state_data.is_a?(Hash) ? @task.state_data : {}
      state.fetch("auditor", {}).fetch("rework_count", 0).to_i
    end

    def missing_required_signals(required_signals, signals)
      Array(required_signals).map(&:to_s).reject { |signal| signals[signal] }
    end
  end
end
