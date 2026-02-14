require "fileutils"
require "diffy"

module Api
  module V1
    class HooksController < ActionController::API
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

        session_id = params[:session_id].presence || params[:agent_session_id].presence
        session_key = params[:session_key].presence || params[:agent_session_key].presence
        updates[:agent_session_id] = session_id if session_id.present? && task.agent_session_id.blank?
        updates[:agent_session_key] = session_key if session_key.present? && task.agent_session_key.blank?

        effective_session_id = updates[:agent_session_id].presence || task.agent_session_id

        activity = persist_agent_activity(task, effective_session_id)

        if effective_session_id.present?
          begin
            tpath = TranscriptParser.transcript_path(effective_session_id)
            if tpath
              task_run_record = TaskRun.find_by(run_id: effective_session_id) || TaskRun.find_by(task_id: task.id)
              AgentTranscript.capture_from_jsonl!(tpath, task: task, task_run: task_run_record, session_id: effective_session_id)
            end
          rescue StandardError => e
            Rails.logger.warn("[HooksController] Failed to archive transcript: #{e.message}")
          end
        end

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

        # Auto-review gate
        auto_review = Pipeline::AutoReviewService.new(task, findings: findings)
        review_result = auto_review.evaluate

        case review_result[:decision]
        when :done
          updates[:status] = "done"
          updates[:completed_at] = Time.current if task.respond_to?(:completed_at)
        when :requeue
          updates[:status] = "up_next"
          updates[:error_message] = review_result[:reason]
        when :in_review
          # default, already set
        end

        Rails.logger.info("[AutoReview] task=##{task.id} decision=#{review_result[:decision]} reason=#{review_result[:reason]}")

        task.update!(updates)

        GenerateDiffsJob.perform_later(task.id, merged_files) if merged_files.any?

        KanbanChannel.broadcast_refresh(
          task.board_id,
          task_id: task.id,
          action: "update",
          old_status: old_status,
          new_status: task.status
        )

        detect_and_record_rate_limits(task, findings)

        render json: { success: true, task_id: task.id, status: task.status }
      end

      # POST /api/v1/hooks/task_outcome
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

        version = payload["version"].to_s
        run_id = payload["run_id"].to_s
        ended_at_raw = payload["ended_at"].to_s
        needs_follow_up = ActiveModel::Type::Boolean.new.cast(payload["needs_follow_up"]) || false
        recommended_action = payload["recommended_action"].to_s.presence || "in_review"

        unless version == "1"
          return render json: { error: "invalid version" }, status: :unprocessable_entity
        end

        unless run_id.match?(/\A[0-9a-fA-F\-]{36}\z/)
          return render json: { error: "invalid run_id" }, status: :unprocessable_entity
        end

        allowed_actions = TaskRun::RECOMMENDED_ACTIONS
        unless allowed_actions.include?(recommended_action)
          return render json: { error: "invalid recommended_action" }, status: :unprocessable_entity
        end

        next_prompt = payload["next_prompt"].to_s
        if needs_follow_up && recommended_action == "requeue_same_task" && next_prompt.blank?
          return render json: { error: "next_prompt required for requeue_same_task" }, status: :unprocessable_entity
        end

        ended_at =
          begin
            ended_at_raw.present? ? Time.iso8601(ended_at_raw) : Time.current
          rescue StandardError
            Time.current
          end

        idempotent = false

        task_run = nil
        existing = TaskRun.find_by(run_id: run_id)
        if existing
          return render json: { success: true, idempotent: true, task_id: task.id, run_number: existing.run_number, status: task.status }
        end

        old_status = task.status

        Task.transaction do
          task.lock!

          task_run = TaskRun.find_by(run_id: run_id)
          if task_run
            idempotent = true
            next
          end

          run_number = task.run_count.to_i + 1

          task_run = TaskRun.create!(
            task: task,
            run_id: run_id,
            run_number: run_number,
            ended_at: ended_at,
            needs_follow_up: needs_follow_up,
            recommended_action: recommended_action,
            summary: payload["summary"],
            achieved: Array(payload["achieved"]),
            evidence: Array(payload["evidence"]),
            remaining: Array(payload["remaining"]),
            next_prompt: payload["next_prompt"],
            model_used: payload["model_used"],
            openclaw_session_id: payload["openclaw_session_id"],
            openclaw_session_key: payload["openclaw_session_key"],
            raw_payload: payload
          )

          task.runner_leases.where(released_at: nil).update_all(released_at: Time.current)

          base_updates = {
            run_count: run_number,
            last_run_id: run_id,
            last_outcome_at: ended_at,
            last_needs_follow_up: needs_follow_up,
            last_recommended_action: recommended_action,
            agent_claimed_at: nil
          }

          case recommended_action
          when "requeue_same_task"
            task.update!(base_updates.merge(status: :in_review))
          else
            task.update!(
              base_updates.merge(
                status: :in_review
              )
            )
          end
        end

        # Pipeline advancement on outcome
        advance_pipeline(task, recommended_action, payload) if task.pipeline_active?

        KanbanChannel.broadcast_refresh(
          task.board_id,
          task_id: task.id,
          action: "update",
          old_status: old_status,
          new_status: task.status
        )

        render json: { success: true, idempotent: idempotent, task_id: task.id, run_number: task_run&.run_number, status: task.status }
      rescue ActiveRecord::RecordNotUnique
        existing = TaskRun.find_by(run_id: params[:run_id].to_s)
        render json: { success: true, idempotent: true, task_id: task.id, run_number: existing&.run_number, status: task.status }
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

      # Pipeline advancement logic based on outcome webhook
      def advance_pipeline(task, recommended_action, payload)
        config = Pipeline::TriageService.config
        max_retries = config[:max_retries] || 3
        escalate = config[:escalate_on_retry] != false

        case recommended_action
        when "in_review"
          # Standard completion
          task.advance_pipeline_stage!("completed", action: "in_review", summary: payload["summary"])

        when "requeue_same_task"
          # Retry — check retry count
          retry_count = task.task_runs.count
          if retry_count >= max_retries
            if escalate
              escalate_model_tier!(task)
            else
              task.advance_pipeline_stage!("failed", action: "requeue_exceeded_retries", retries: retry_count)
            end
          else
            # Reset to context_ready for re-routing (keeps context, re-routes model)
            task.advance_pipeline_stage!("context_ready", action: "requeue_retry", retry: retry_count)
          end

        when "split_into_subtasks"
          task.advance_pipeline_stage!("completed", action: "split_into_subtasks")

        when "prompt_user"
          task.advance_pipeline_stage!("completed", action: "prompt_user")
        end
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Pipeline advancement failed for task ##{task.id}: #{e.class}: #{e.message}")
      end

      # Escalate to next model tier
      def escalate_model_tier!(task)
        config = Pipeline::TriageService.config
        tiers = config[:model_tiers] || {}
        current_model = task.routed_model || task.model || Task::DEFAULT_MODEL

        # Find current tier
        current_tier = nil
        tiers.each do |tier_name, tier_cfg|
          if Array(tier_cfg[:models]).include?(current_model)
            current_tier = tier_name.to_s
            break
          end
        end

        if current_tier
          next_tier = tiers.dig(current_tier.to_sym, :fallback)&.to_s
          if next_tier.present? && next_tier != "null"
            next_models = Array(tiers.dig(next_tier.to_sym, :models))
            if next_models.any?
              task.update_columns(routed_model: next_models.first)
              task.advance_pipeline_stage!("context_ready", action: "escalated", from_tier: current_tier, to_tier: next_tier, new_model: next_models.first)
              return
            end
          end
        end

        # Cannot escalate further
        task.advance_pipeline_stage!("failed", action: "escalation_exhausted", model: current_model)
      end

      def persist_agent_activity(task, session_id)
        activity_lines = []
        activity_lines << "Session: `#{session_id}`" if session_id.present?
        activity_lines << "Live log endpoint: `/api/v1/tasks/#{task.id}/agent_log`"

        return { activity_markdown: activity_lines.join("\n"), output_files: [] } if session_id.blank?

        transcript_path = File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl")
        unless File.exist?(transcript_path)
          archived = Dir.glob(File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl.deleted.*")).first
          transcript_path = archived if archived
        end

        unless File.exist?(transcript_path)
          activity_lines << "Transcript: (file not found on server)"
          return { activity_markdown: activity_lines.join("\n"), output_files: [] }
        end

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

        user = task.user || User.first
        return unless user

        ModelLimit.record_limit!(user, model_name, findings)
        Rails.logger.info("[HooksController] Auto-recorded rate limit for model '#{model_name}' from task ##{task.id}")
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Failed to auto-record rate limit: #{e.message}")
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
