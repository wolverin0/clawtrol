require "fileutils"

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

        task.update!(updates)

        render json: { success: true, task_id: task.id, status: task.status }
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
