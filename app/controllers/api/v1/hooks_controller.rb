# frozen_string_literal: true

require "fileutils"
require "diffy"

module Api
  module V1
    class HooksController < ActionController::API
      include Api::RateLimitable
      include Api::HookAuthentication

      # Hooks are less frequent but more critical — 30/min per IP
      before_action -> { rate_limit!(limit: 30, window: 60, key_suffix: "hooks") }
      before_action :authenticate_hook_token!

      # POST /api/v1/hooks/agent_complete
      def agent_complete
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
          # Description gets updated after we determine session_id and (optionally) persist transcript
          status: "in_review",
          assigned_to_agent: true,
          assigned_at: task.assigned_at || Time.current
        }

        # Auto-link session_id/session_key on first hook
        raw_session_id = params[:session_id].presence || params[:agent_session_id].presence ||
                         params.dig(:hook, :session_id).presence || params.dig(:hook, :agent_session_id).presence
        session_id = extract_session_uuid(raw_session_id)
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


# --- P0: persist structured output to TaskRun ---
        hook_run_id = resolved_run_id.presence || effective_session_id.presence || SecureRandom.uuid
        task_run = task.task_runs.find_by(run_id: hook_run_id)
        if task_run
          run_updates = {}
          run_updates[:agent_output] = findings if findings.present? && task_run.agent_output.blank?
          run_updates[:agent_activity_md] = activity[:activity_markdown] if activity[:activity_markdown].present? && task_run.agent_activity_md.blank?
          run_updates[:prompt_used] = task.effective_prompt if task_run.prompt_used.blank?
          task_run.update_columns(run_updates) if run_updates.any?
        else
          # No matching TaskRun — create one for this completion
          next_num = (task.task_runs.maximum(:run_number) || 0) + 1
          task.task_runs.create!(
            run_id: hook_run_id,
            run_number: next_num,
            agent_output: findings,
            agent_activity_md: activity[:activity_markdown],
            prompt_used: task.effective_prompt,
            summary: findings.to_s.truncate(500)
          )
        end

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

        persist_activity_event(task, {
          run_id: resolved_run_id.presence || effective_session_id.presence || "task-#{task.id}",
          source: "hook",
          level: "info",
          event_type: "final_summary",
          message: findings.to_s.truncate(5_000),
          seq: next_event_seq(task, resolved_run_id.presence || effective_session_id.presence || "task-#{task.id}"),
          payload: {
            session_id: effective_session_id,
            session_key: params[:session_key].presence || params[:agent_session_key].presence
          }
        })

        # Pipeline phase handoff: if the task is in a pipeline, advance to next stage.
        # The router updates the model recommendation for the next stage.
        pipeline_advanced = advance_pipeline_stage(task)

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
        task = find_task_from_params
        return render json: { error: "task not found" }, status: :not_found unless task

        payload = params.permit(
          :version, :run_id, :ended_at, :needs_follow_up, :recommended_action,
          :next_prompt, :summary, :model_used, :openclaw_session_id,
          :openclaw_session_key, :task_id,
          achieved: [], evidence: [], remaining: [],
          run: {}, tokens: {}, usage: {}
        ).to_h

        # Preserve optional token contracts even when nested payloads include dynamic keys.
        unsafe_payload = params.to_unsafe_h
        payload["run"] = unsafe_payload["run"] if unsafe_payload["run"].is_a?(Hash)
        payload["tokens"] = unsafe_payload["tokens"] if unsafe_payload["tokens"].is_a?(Hash)
        payload["usage"] = unsafe_payload["usage"] if unsafe_payload["usage"].is_a?(Hash)

        result = TaskOutcomeService.call(task, payload)

        if result.success?
          persist_activity_event(task, {
            run_id: payload["run_id"],
            source: "hook",
            level: "info",
            event_type: "status",
            message: "Outcome received (#{payload['recommended_action'] || 'in_review'})",
            seq: next_event_seq(task, payload["run_id"]),
            payload: payload
          })

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

      # POST /api/v1/hooks/agent_activity
      # Persists append-only activity events independent of transcript cleanup.
      def agent_activity
        task = find_task_from_params
        return render json: { error: "task not found" }, status: :not_found unless task

        events = params[:events].presence || [params.permit(:run_id, :source, :level, :event_type, :message, :seq, :created_at, payload: {}).to_h]
        result = AgentActivityIngestionService.call(task: task, events: events)

        render json: {
          success: true,
          task_id: task.id,
          created: result.created,
          duplicates: result.duplicates,
          errors: result.errors
        }
      end

      # POST /api/v1/hooks/runtime_events
      # Runtime events v2: streaming-friendly event batches for runtime panel.
      def runtime_events
        version = params[:version].to_i
        return render json: { error: "invalid version" }, status: :unprocessable_entity unless version == 2

        events = extract_runtime_events(params)
        return render json: { error: "events missing" }, status: :unprocessable_entity if events.blank?

        task = find_task_from_params
        task ||= find_task_from_runtime_events(events)
        return render json: { error: "task not found" }, status: :not_found unless task

        run_id = resolved_run_id.presence ||
          params[:session_id].presence ||
          params[:agent_session_id].presence ||
          task.last_run_id.presence ||
          task.agent_session_id.presence ||
          "task-#{task.id}"


        result = RuntimeEventsIngestionService.call(
          task: task,
          events: events,
          run_id: run_id,
          source: "runtime_hook"
        )

        render json: {
          success: true,
          task_id: task.id,
          created: result.created,
          duplicates: result.duplicates,
          errors: result.errors
        }
      end

      # POST /api/v1/hooks/zeroclaw_auditor
      # Explicit webhook trigger for auditor runs (external orchestrators).
      def zeroclaw_auditor
        task = find_task_from_params
        return render json: { error: "task not found" }, status: :not_found unless task

        unless task.status == "in_review"
          render json: { error: "task must be in_review", task_id: task.id, status: task.status }, status: :unprocessable_entity
          return
        end

        unless task.assigned_to_agent? && Zeroclaw::AuditableTask.auditable?(task)
          render json: { error: "task not eligible for auditor", task_id: task.id }, status: :unprocessable_entity
          return
        end

        force = ActiveModel::Type::Boolean.new.cast(params[:force])
        ZeroclawAuditorJob.perform_later(task.id, trigger: "webhook", force: force)

        render json: {
          success: true,
          task_id: task.id,
          queued: true,
          trigger: "webhook",
          force: force
        }
      end

      private

      # Extract clean UUID from OpenClaw session identifiers
      # Handles formats like "agent:main:subagent:UUID" or plain "UUID"
      def extract_session_uuid(raw_id)
        return nil if raw_id.blank?
        raw = raw_id.to_s.strip
        # OpenClaw subagent format: "agent:main:subagent:UUID"
        if raw.include?(":")
          parts = raw.split(":")
          candidate = parts.last
          return candidate if candidate.match?(/\A[a-zA-Z0-9_\-]+\z/)
        end
        # Plain UUID or session ID
        return raw if raw.match?(/\A[a-zA-Z0-9_\-]+\z/)
        nil
      end

      # P0: resolve run_id from both top-level and wrapped params
      def resolved_run_id
        params[:run_id].presence || params.dig(:hook, :run_id).presence
      end

      def find_task_from_params
        session_key = params[:session_key].presence || params[:agent_session_key].presence
        session_id = params[:session_id].presence || params[:agent_session_id].presence
        task_id = params[:task_id].presence

        (Task.find_by(agent_session_key: session_key) if session_key.present?) ||
          (Task.find_by(agent_session_id: session_id) if session_id.present?) ||
          (Task.find_by(id: task_id) if task_id.present?)
      end

      def find_task_from_runtime_events(events)
        candidate = Array(events).find { |event| event.is_a?(Hash) && (event["task_id"].present? || event[:task_id].present?) }
        task_id = candidate && (candidate["task_id"] || candidate[:task_id])
        return nil if task_id.blank?

        Task.find_by(id: task_id)
      end

      def extract_runtime_events(params)
        events = params[:events]
        return events if events.present?

        single = params[:event].presence || params[:runtime_event].presence
        return [single] if single.present?

        []
      end

      def persist_agent_activity(task, session_id)
        activity_lines = []
        activity_lines << "Session: `#{session_id}`" if session_id.present?
        activity_lines << "Live log endpoint: `/api/v1/tasks/#{task.id}/agent_log`"

        return { activity_markdown: activity_lines.join("\n"), output_files: [] } if session_id.blank?

        # SECURITY: Sanitize session_id to prevent path traversal.
        # Session IDs are alphanumeric with hyphens/underscores only.
        # Extract UUID from prefixed formats (e.g. "agent:main:subagent:UUID")
        clean_sid = extract_session_uuid(session_id) || session_id.to_s.gsub(/[^a-zA-Z0-9\-_]/, "")
        if clean_sid.blank?
          Rails.logger.warn("[HooksController] Rejected suspicious session_id: #{session_id.inspect}")
          activity_lines << "Transcript: (invalid session_id)"
          return { activity_markdown: activity_lines.join("\n"), output_files: [] }
        end
        sanitized_sid = clean_sid

        # Locate transcript file (current or archived)
        sessions_dir = File.expand_path("~/.openclaw/agents/main/sessions")
        transcript_path = File.join(sessions_dir, "#{sanitized_sid}.jsonl")

        # SECURITY: Verify resolved path is within the expected directory
        path_safe = begin
          File.realpath(transcript_path).start_with?(File.realpath(sessions_dir) + "/")
        rescue Errno::ENOENT
          false
        end
        unless path_safe
          Rails.logger.warn("[HooksController] Path escape attempt with session_id: #{session_id.inspect}")
          activity_lines << "Transcript: (file not found on server)"
          return { activity_markdown: activity_lines.join("\n"), output_files: [] }
        end

        unless File.exist?(transcript_path)
          archived = Dir.glob(File.join(sessions_dir, "#{sanitized_sid}.jsonl.deleted.*")).first
          transcript_path = archived if archived
        end

        unless transcript_path && File.exist?(transcript_path)
          activity_lines << "Transcript: (file not found on server)"
          return { activity_markdown: activity_lines.join("\n"), output_files: [] }
        end

        # Copy transcript to a stable, UI-accessible location under Rails.root/storage
        rel_dir = "storage/agent_activity"
        abs_dir = Rails.root.join(rel_dir)
        FileUtils.mkdir_p(abs_dir)

        rel_copy_path = File.join(rel_dir, "task-#{task.id}-session-#{sanitized_sid}.jsonl")
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

        # Common rate limit patterns from various providers
        rate_limit_patterns = [
          /usage\s+limit.*?\((\w+)\s+plan\)/i,          # "usage limit (plus plan)"
          /rate\s+limit.*?model[:\s]+(\w+)/i,            # "rate limit... model: codex"
          /hit\s+.*?limit/i                              # "hit your ... limit"
        ]

        is_rate_limit = rate_limit_patterns.any? { |p| findings.match?(p) }
        return unless is_rate_limit

        # Try to determine which model hit the limit
        model_name = task.model.presence || detect_model_from_text(findings)
        return unless model_name.present? && Task::MODELS.include?(model_name)

        # Find the user who owns this task to register the limit
        # BUG FIX: never fall back to User.first — that would attribute limits to wrong user
        user = task.user
        return unless user

        ModelLimit.record_limit!(user, model_name, findings)
        Rails.logger.info("[HooksController] Auto-recorded rate limit for model '#{model_name}' from task ##{task.id}")
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Failed to auto-record rate limit: #{e.message}")
      end

      # Pipeline phase handoff: advance task to the next pipeline stage after
      # agent_complete fires. If the pipeline has a next phase, auto-advance
      # and update the model recommendation. Returns true if advanced.
      # Reloads the task after attempt to ensure response reflects persisted state.
      def advance_pipeline_stage(task)
        return false if task.pipeline_unstarted? || task.pipeline_pipeline_done?

        router = ClawRouterService.new(task)
        result = router.advance!
        task.reload unless result # Ensure in-memory state matches DB on failure
        result
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Pipeline advance failed for task ##{task.id}: #{e.message}")
        task.reload rescue nil
        false
      end

      # Try to extract model name from error text
      def detect_model_from_text(text)
        return "codex" if text =~ /codex|chatgpt|gpt-5/i
        return "opus" if text =~ /opus|claude/i
        return "gemini" if text =~ /gemini/i
        return "glm" if text =~ /glm|zhipu|z\.ai/i
        return "sonnet" if text =~ /sonnet/i
        nil
      end

      # Record agent output as an AgentMessage for inter-agent chat history.
      # If the task has a parent_task or source_task, also record a handoff message.
      def record_agent_output_message(task, findings, session_id)
        return if findings.blank?

        model = task.model.presence || params[:model].presence
        agent_name = task.agent_persona&.name

        # Record the output on this task
        AgentMessage.record_output!(
          task: task,
          content: findings,
          summary: findings.truncate(500),
          model: model,
          session_id: session_id,
          agent_name: agent_name,
          metadata: { run_id: resolved_run_id, hook: "agent_complete" }
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
            metadata: { run_id: resolved_run_id, source_hook: "agent_complete" }
          )
        end
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Failed to record agent message for task ##{task.id}: #{e.message}")
      end

      def persist_activity_event(task, attrs)
        AgentActivityIngestionService.call(task: task, events: [attrs])
      rescue StandardError => e
        Rails.logger.warn("[HooksController] Failed to persist activity event for task ##{task.id}: #{e.message}")
      end

      def next_event_seq(task, run_id)
        AgentActivityEvent.where(task_id: task.id, run_id: run_id.to_s).maximum(:seq).to_i + 1
      end
    end
  end
end
