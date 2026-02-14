# frozen_string_literal: true

require "fileutils"
require "diffy"

module Api
  module V1
    class HooksController < ActionController::API
      include Api::RateLimitable

      # Hooks are less frequent but more critical — 30/min per IP
      before_action -> { rate_limit!(limit: 30, window: 60, key_suffix: "hooks") }

      # POST /api/v1/hooks/agent_complete
      def agent_complete
        token = request.headers["X-Hook-Token"].to_s
        configured_token = Rails.application.config.hooks_token.to_s
        unless configured_token.present? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, configured_token)
          return render json: { error: "unauthorized" }, status: :unauthorized
        end

        task = find_task_from_params
        return render json: { error: "task not found" }, status: :not_found unless task

        findings = params[:findings].presence || params[:output].presence

        # If no findings provided, try to extract from transcript
        transcript_files = []
        if findings.blank?
          sid = params[:session_id].presence || params[:agent_session_id].presence || task.agent_session_id
          if sid.present?
            tpath = TranscriptParser.transcript_path(sid)
            if tpath
              findings = TranscriptParser.extract_summary(tpath)
              transcript_files = TranscriptParser.extract_output_files(tpath)
            end
          end
          findings = "Agent completed (no findings provided)" if findings.blank?
        end

        updates = {
          status: "in_review",
          assigned_to_agent: true,
          assigned_at: task.assigned_at || Time.current
        }

        # Auto-link session_id/session_key on first hook
        session_id = params[:session_id].presence || params[:agent_session_id].presence
        session_key = params[:session_key].presence || params[:agent_session_key].presence
        updates[:agent_session_id] = session_id if session_id.present? && task.agent_session_id.blank?
        updates[:agent_session_key] = session_key if session_key.present? && task.agent_session_key.blank?

        effective_session_id = updates[:agent_session_id].presence || task.agent_session_id

        # Persist agent transcript into a stable file within the Rails app (storage/agent_activity)
        activity = persist_agent_activity(task, effective_session_id)

        provided_files = params[:output_files].presence || params[:files].presence
        extracted_from_findings = task.extract_output_files_from_findings(findings)

        candidate_files = task.normalized_output_files(provided_files)
        candidate_files = extracted_from_findings if candidate_files.blank?
        candidate_files += Array(activity[:output_files]) if activity[:output_files].present?
        candidate_files += transcript_files if transcript_files.present?

        if task.agent_session_id.present? || updates[:agent_session_id].present?
          candidate_files += task.extract_output_files_from_transcript_commit
        end

        merged_files = task.normalized_output_files((task.output_files || []) + candidate_files)
        updates[:output_files] = merged_files if merged_files.any?

        # Preserve original description before first hook overwrite
        if task.original_description.blank?
          current = task.description.to_s
          if current.include?("\n\n---\n\n")
            _top, rest = current.split("\n\n---\n\n", 2)
            updates[:original_description] = rest if rest.present?
          elsif !current.start_with?("## Agent Activity") && !current.start_with?("## Agent Output")
            updates[:original_description] = current if current.present?
          end
        end

        updates[:description] = updated_description(task.description.to_s, findings, activity[:activity_markdown])

        old_status = task.status
        task.update!(updates)

        # Generate diffs for output files (async to avoid blocking the response)
        GenerateDiffsJob.perform_later(task.id, merged_files) if merged_files.any?

        # Notify board clients (KanbanRefresh) that a background agent completed work.
        KanbanChannel.broadcast_refresh(
          task.board_id,
          task_id: task.id,
          action: "update",
          old_status: old_status,
          new_status: task.status
        )

        # Auto-detect rate limits from findings/error messages and register them
        detect_and_record_rate_limits(task, findings)

        # Record agent output as an inter-agent message for chat history
        record_agent_output_message(task, findings, effective_session_id)

        # Pipeline advancement: if pipeline-enabled, advance through stages
        pipeline_advanced = advance_pipeline(task)

        render json: {
          success: true,
          task_id: task.id,
          status: task.status,
          pipeline_stage: task.pipeline_stage,
          pipeline_advanced: pipeline_advanced
        }
      end

      # POST /api/v1/hooks/task_outcome
      #
      # OpenClaw completion hook (OutcomeContract v1). This is intentionally
      # idempotent via run_id (UUID).
      def task_outcome
        token = request.headers["X-Hook-Token"].to_s
        configured_token = Rails.application.config.hooks_token.to_s
        unless configured_token.present? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, configured_token)
          return render json: { error: "unauthorized" }, status: :unauthorized
        end

        task = find_task_from_params
        return render json: { error: "task not found" }, status: :not_found unless task

        payload = params.permit(
          :version, :run_id, :ended_at, :needs_follow_up, :recommended_action,
          :next_prompt, :summary, :model_used, :openclaw_session_id,
          :openclaw_session_key, :task_id,
          achieved: [], evidence: [], remaining: []
        ).to_h

        result = TaskOutcomeService.call(task, payload)

        if result.success?
          # Pipeline advancement after outcome processing
          advance_pipeline(task)

          render json: {
            success: true,
            idempotent: result.idempotent?,
            task_id: task.id,
            run_number: result.task_run&.run_number,
            status: task.reload.status
          }
        else
          render json: { error: result.error }, status: result.error_status
        end
      end

      private

      def find_task_from_params
        session_key = params[:session_key].presence
        session_id = params[:session_id].presence
        task_id = params[:task_id].presence

        (Task.find_by(agent_session_key: session_key) if session_key.present?) ||
          (Task.find_by(agent_session_id: session_id) if session_id.present?) ||
          (Task.find_by(id: task_id) if task_id.present?)
      end

      def persist_agent_activity(task, session_id)
        activity_lines = []
        activity_lines << "Session: `#{session_id}`" if session_id.present?
        activity_lines << "Live log endpoint: `/api/v1/tasks/#{task.id}/agent_log`"

        return { activity_markdown: activity_lines.join("\n"), output_files: [] } if session_id.blank?

        # Locate transcript file (current or archived)
        transcript_path = File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl")
        unless File.exist?(transcript_path)
          archived = Dir.glob(File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl.deleted.*")).first
          transcript_path = archived if archived
        end

        unless File.exist?(transcript_path)
          activity_lines << "Transcript: (file not found on server)"
          return { activity_markdown: activity_lines.join("\n"), output_files: [] }
        end

        # Copy transcript to a stable, UI-accessible location under Rails.root/storage
        rel_dir = "storage/agent_activity"
        abs_dir = Rails.root.join(rel_dir)
        FileUtils.mkdir_p(abs_dir)

        rel_copy_path = File.join(rel_dir, "task-#{task.id}-session-#{session_id}.jsonl")
        abs_copy_path = Rails.root.join(rel_copy_path)
        FileUtils.cp(transcript_path, abs_copy_path)

        activity_lines << "Transcript saved: `#{rel_copy_path}`"

        size = File.size(abs_copy_path)
        if size <= 200_000
          content = File.read(abs_copy_path, encoding: "UTF-8")
          activity_lines << ""
          activity_lines << "<details><summary>Show transcript (#{size} bytes)</summary>"
          activity_lines << ""
          activity_lines << "```jsonl"
          activity_lines << content
          activity_lines << "```"
          activity_lines << ""
          activity_lines << "</details>"
        else
          activity_lines << "(Transcript is #{size} bytes; open the saved file from Output Files.)"
        end

        { activity_markdown: activity_lines.join("\n"), output_files: [rel_copy_path] }
      rescue StandardError => e
        Rails.logger.warn("[HooksController#agent_complete] Failed to persist agent activity for task #{task.id}: #{e.class}: #{e.message}")
        { activity_markdown: "(Failed to persist transcript: #{e.class})", output_files: [] }
      end

      # Auto-detect rate limit errors in agent findings and register model limits
      def detect_and_record_rate_limits(task, findings)
        return if findings.blank?

        rate_limit_patterns = [
          /usage\s+limit.*?\((\w+)\s+plan\)/i,
          /rate\s+limit.*?model[:\s]+(\w+)/i,
          /hit\s+.*?limit/i
        ]

        is_rate_limit = rate_limit_patterns.any? { |p| findings.match?(p) }
        return unless is_rate_limit

        model_name = task.model.presence || detect_model_from_text(findings)
        return unless model_name.present? && Task::MODELS.include?(model_name)

        user = task.user
        return unless user

        ModelLimit.record_limit!(user, model_name, findings)
        Rails.logger.info("[HooksController] Auto-recorded rate limit for model '#{model_name}' from task ##{task.id}")
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Failed to auto-record rate limit: #{e.message}")
      end

      # Pipeline advancement: process pipeline stages if task has pipeline enabled
      def advance_pipeline(task)
        return false unless task.pipeline_enabled?
        return false unless task.pipeline_stage.present?

        # If task is in executing stage, the outcome determines next action
        if task.pipeline_stage == "executing"
          recommended = params[:recommended_action].to_s

          case recommended
          when "complete", "archive"
            task.advance_pipeline_stage!("completed", action: recommended)
          when "requeue_same_task"
            retry_count = task.pipeline_log.to_a.count { |e| e["stage"] == "context_ready" && e["retry"] }
            if retry_count < 3
              task.advance_pipeline_stage!("context_ready", retry: true, retry_count: retry_count + 1)
              PipelineProcessorJob.perform_later(task.id)
            else
              task.advance_pipeline_stage!("failed", reason: "max_retries_exceeded")
            end
          when "escalate"
            escalate_model_tier!(task)
            PipelineProcessorJob.perform_later(task.id)
          else
            task.advance_pipeline_stage!("completed", action: recommended.presence || "default_complete")
          end
          true
        else
          false
        end
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Pipeline advance failed for task ##{task.id}: #{e.message}")
        false
      end

      # Escalate to next model tier when current model hits limits
      def escalate_model_tier!(task)
        config = Pipeline::TriageService.config
        tiers = config[:model_tiers] || {}

        current_model = task.routed_model || task.model
        current_tier = tiers.find { |_name, cfg| Array(cfg[:models]).include?(current_model) }

        if current_tier
          tier_name, tier_cfg = current_tier
          fallback = tier_cfg[:fallback]&.to_s
          if fallback.present? && fallback != "null" && tiers[fallback.to_sym]
            new_model = Array(tiers[fallback.to_sym][:models]).first
            if new_model
              task.update_columns(routed_model: new_model)
              task.advance_pipeline_stage!("context_ready", escalated_from: current_model, escalated_to: new_model)
              return
            end
          end
        end

        task.advance_pipeline_stage!("failed", reason: "no_escalation_available", current_model: current_model)
      end

      # Record agent output as an AgentMessage for inter-agent chat history
      def record_agent_output_message(task, findings, session_id)
        return if findings.blank?
        return unless defined?(AgentMessage)

        model = task.model.presence || params[:model].presence
        agent_name = task.agent_persona&.name

        AgentMessage.record_output!(
          task: task,
          content: findings,
          summary: findings.truncate(500),
          model: model,
          session_id: session_id,
          agent_name: agent_name,
          metadata: { run_id: params[:run_id], hook: "agent_complete" }
        )

        # If this task feeds into a follow-up or parent, record handoff
        target = task.followup_task || task.parent_task
        if target.present?
          AgentMessage.record_handoff!(
            from_task: task,
            to_task: target,
            content: findings,
            summary: findings.truncate(500),
            model: model,
            session_id: session_id,
            agent_name: agent_name,
            metadata: { run_id: params[:run_id], source_hook: "agent_complete" }
          )
        end
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Failed to record agent message for task ##{task.id}: #{e.message}")
      end

      def detect_model_from_text(text)
        return "codex" if text =~ /codex|chatgpt|gpt-5/i
        return "opus" if text =~ /opus|claude/i
        return "gemini" if text =~ /gemini/i
        return "glm" if text =~ /glm|zhipu|z\.ai/i
        return "sonnet" if text =~ /sonnet/i
        nil
      end

      def updated_description(current_description, findings, activity_markdown)
        activity_marker = "## Agent Activity"
        output_marker = "## Agent Output"

        activity_markdown = activity_markdown.presence || "(No transcript available)"

        top_block = "#{activity_marker}\n\n#{activity_markdown}\n\n#{output_marker}\n\n#{findings}"

        if current_description.start_with?(activity_marker) || current_description.start_with?(output_marker)
          if current_description.include?("\n\n---\n\n")
            _old_top, rest = current_description.split("\n\n---\n\n", 2)
            return "#{top_block}\n\n---\n\n#{rest}"
          end

          return top_block
        end

        if current_description.blank?
          top_block
        else
          "#{top_block}\n\n---\n\n#{current_description}"
        end
      end
    end
  end
end
