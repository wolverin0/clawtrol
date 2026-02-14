# frozen_string_literal: true

module Pipeline
  class AutoReviewService
    # Evaluates agent output and decides disposition:
    # :done - task completed successfully, move to done
    # :requeue - output incomplete/failed, retry with feedback
    # :in_review - ambiguous, needs human review
    #
    # Returns { decision: :done/:requeue/:in_review, reason: "..." }

    MAX_AUTO_REQUEUES = 1

    def initialize(task, findings:)
      @task = task
      @findings = findings.to_s
    end

    def evaluate
      # If already requeued once, always send to review
      if @task.run_count.to_i > MAX_AUTO_REQUEUES
        return { decision: :in_review, reason: "Already retried #{@task.run_count} times" }
      end

      # 1. Empty or trivial output → requeue
      if output_empty?
        return { decision: :requeue, reason: "Agent produced no meaningful output" }
      end

      # 2. Agent reported failure explicitly
      if output_reports_failure?
        return { decision: :requeue, reason: "Agent reported failure: #{extract_error_summary}" }
      end

      # 3. Has validation_command → run it
      if @task.validation_command.present?
        passed, output = run_validation
        if passed
          return { decision: :done, reason: "Validation passed: #{@task.validation_command}" }
        else
          return { decision: :requeue, reason: "Validation failed: #{output.to_s.truncate(500)}" }
        end
      end

      # 4. Research/docs tasks with substantial output → done
      if research_or_docs_task? && output_substantial?
        return { decision: :done, reason: "Research/docs task with substantial output" }
      end

      # 5. Quick-fix/trivial with output → done
      if trivial_task? && output_substantial?
        return { decision: :done, reason: "Trivial task completed with output" }
      end

      # 6. Default: in_review for human
      { decision: :in_review, reason: "Requires human review" }
    end

    private

    def output_empty?
      clean = @findings.gsub(/agent completed|no findings/i, "").strip
      clean.length < 20
    end

    def output_reports_failure?
      @findings.match?(/(?:failed|error|❌|could not|unable to|exception|crash)/i) &&
        !@findings.match?(/(?:fixed|resolved|passed|✅|successfully)/i)
    end

    def extract_error_summary
      # Find first line with error-like content
      @findings.lines.find { |l| l.match?(/(?:error|fail|❌|unable|exception)/i) }&.strip&.truncate(200) || "unknown error"
    end

    def run_validation
      cmd = @task.validation_command
      return [false, "no command"] if cmd.blank?

      # Run with timeout, in the project directory if available
      project_dir = detect_project_dir
      full_cmd = "cd #{project_dir} && timeout 60s #{cmd}" if project_dir
      full_cmd ||= "timeout 60s #{cmd}"

      output = `#{full_cmd} 2>&1`
      [($?.success?), output.to_s.truncate(1000)]
    rescue StandardError => e
      [false, "Validation error: #{e.message}"]
    end

    def detect_project_dir
      board_name = @task.board&.name&.downcase
      # Map known boards to directories
      case board_name
      when "clawdeck" then File.expand_path("~/clawdeck")
      when "personal dashboard" then "/mnt/pyapps/personaldashboard"
      when "whatsapp bot" then "/mnt/pyapps/whatsappbot-prod - Copy - Copy/whatsappbot-final"
      else nil
      end
    end

    def research_or_docs_task?
      tags = Array(@task.tags).map(&:downcase)
      pipeline_type = @task.pipeline_type.to_s.downcase

      tags.any? { |t| %w[research docs documentation investigate explore].include?(t) } ||
        %w[research].include?(pipeline_type)
    end

    def trivial_task?
      pipeline_type = @task.pipeline_type.to_s.downcase
      tags = Array(@task.tags).map(&:downcase)

      %w[quick-fix].include?(pipeline_type) ||
        tags.any? { |t| %w[quick trivial hotfix typo small].include?(t) }
    end

    def output_substantial?
      @findings.length > 100
    end
  end
end
