require "fileutils"
require "diffy"

module Api
  module V1
    class HooksController < ActionController::API
      # POST /api/v1/hooks/agent_complete
      def agent_complete
        token = request.headers["X-Hook-Token"] || params[:token]
        unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, Rails.application.config.hooks_token.to_s)
          return render json: { error: "unauthorized" }, status: :unauthorized
        end

        task = find_task_from_params
        return render json: { error: "task not found" }, status: :not_found unless task

        findings = params[:findings].presence ||
                   params[:output].presence ||
                   "Agent completed (no findings provided)"

        updates = {
          # Description gets updated after we determine session_id and (optionally) persist transcript
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

        if task.agent_session_id.present? || updates[:agent_session_id].present?
          candidate_files += task.extract_output_files_from_transcript_commit
        end

        merged_files = task.normalized_output_files((task.output_files || []) + candidate_files)
        updates[:output_files] = merged_files if merged_files.any?

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

        render json: { success: true, task_id: task.id, status: task.status }
      end

      # POST /api/v1/hooks/task_outcome
      #
      # OpenClaw completion hook (OutcomeContract v1). This is intentionally
      # idempotent via run_id (UUID).
      def task_outcome
        token = request.headers["X-Hook-Token"] || params[:token]
        unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, Rails.application.config.hooks_token.to_s)
          return render json: { error: "unauthorized" }, status: :unauthorized
        end

        task = Task.find_by(id: params[:task_id])
        return render json: { error: "task not found" }, status: :not_found unless task

        payload = params.to_unsafe_h

        version = payload["version"].to_s
        run_id = payload["run_id"].to_s
        ended_at_raw = payload["ended_at"].to_s
        needs_follow_up = ActiveModel::Type::Boolean.new.cast(payload["needs_follow_up"])
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

          # Re-check under lock for race conditions.
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

          # Release any runner lease: the run is over, even if we're requeueing.
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
            # Follow-up stays on the same card, BUT we do not auto-requeue.
            # OpenClaw must prompt the user and only requeue on explicit approval.
            task.update!(base_updates.merge(status: :in_review))
          else
            # Default: keep in review for human decision.
            task.update!(
              base_updates.merge(
                status: :in_review
              )
            )
          end
        end

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

      def updated_description(current_description, findings, activity_markdown)
        activity_marker = "## Agent Activity"
        output_marker = "## Agent Output"

        activity_markdown = activity_markdown.presence || "(No transcript available)"

        top_block = "#{activity_marker}\n\n#{activity_markdown}\n\n#{output_marker}\n\n#{findings}"

        if current_description.start_with?(activity_marker) || current_description.start_with?(output_marker)
          # Replace existing top agent sections, preserving remaining description.
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
