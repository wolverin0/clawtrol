# frozen_string_literal: true

require "open3"
require "shellwords"

module Pipeline
  class AutoReviewService
    VALIDATION_TIMEOUT_SECONDS = 60

    def initialize(task, findings:)
      @task = task
      @findings = findings.to_s
    end

    # Rules:
    # 1) Empty output -> requeue
    # 2) Failure markers (without success/fixed markers) -> requeue
    # 3) validation_command present -> run with timeout 60s (pass=done, fail=requeue)
    # 4) Research/docs task with >100 chars -> done
    # 5) Trivial/quick-fix task with >100 chars -> done
    # 6) Default -> in_review
    # 7) If run_count > 1 -> always in_review
    def evaluate
      return { decision: :in_review, reason: "Already retried (run_count=#{@task.run_count})" } if @task.run_count.to_i > 1

      return { decision: :requeue, reason: "Empty output from agent" } if output_empty?
      return { decision: :requeue, reason: "Agent output indicates failure" } if output_reports_failure?

      if @task.validation_command.present?
        passed, output = run_validation(@task.validation_command)
        return { decision: :done, reason: "Validation passed" } if passed

        return { decision: :requeue, reason: "Validation failed: #{output.to_s.truncate(500)}" }
      end

      return { decision: :done, reason: "Research/docs output is substantial" } if research_or_docs_task? && output_substantial?
      return { decision: :done, reason: "Trivial/quick-fix output is substantial" } if trivial_task? && output_substantial?

      { decision: :in_review, reason: "Needs human review" }
    end

    private

    def output_empty?
      @findings.strip.blank?
    end

    def output_reports_failure?
      has_failure = @findings.match?(/❌|\berror\b|\bfailed\b/i)
      has_success = @findings.match?(/✅|\bfixed\b/i)
      has_failure && !has_success
    end

    def run_validation(command)
      project_dir = detect_project_dir
      cmd = "timeout #{VALIDATION_TIMEOUT_SECONDS}s #{command}"

      if project_dir.present?
        escaped_dir = Shellwords.escape(project_dir)
        cmd = "cd #{escaped_dir} && #{cmd}"
      end

      stdout, stderr, status = Open3.capture3("bash", "-lc", cmd)
      [status.success?, [stdout, stderr].join("\n").strip]
    rescue StandardError => e
      [false, e.message]
    end

    def detect_project_dir
      board_name = @task.board&.name.to_s.downcase

      case board_name
      when "clawdeck"
        File.expand_path("~/clawdeck")
      when "personal dashboard"
        "/mnt/pyapps/personaldashboard"
      when "whatsapp bot"
        "/mnt/pyapps/whatsappbot-prod - Copy - Copy/whatsappbot-final"
      end
    end

    def research_or_docs_task?
      tags = normalized_tags
      pipeline_type = @task.pipeline_type.to_s.downcase

      tags.any? { |tag| %w[research docs documentation].include?(tag) } || pipeline_type == "research"
    end

    def trivial_task?
      tags = normalized_tags
      pipeline_type = @task.pipeline_type.to_s.downcase

      %w[quick-fix trivial].include?(pipeline_type) || tags.any? { |tag| %w[quick-fix trivial hotfix typo].include?(tag) }
    end

    def normalized_tags
      Array(@task.tags).map { |tag| tag.to_s.downcase.strip }
    end

    def output_substantial?
      @findings.length > 100
    end
  end
end
