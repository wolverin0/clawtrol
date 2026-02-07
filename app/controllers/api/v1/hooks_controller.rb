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
          description: updated_description(task.description.to_s, findings),
          status: "in_review",
          assigned_to_agent: true,
          assigned_at: task.assigned_at || Time.current
        }

        # Auto-link session_id/session_key on first hook
        session_id = params[:session_id].presence || params[:agent_session_id].presence
        session_key = params[:session_key].presence || params[:agent_session_key].presence
        updates[:agent_session_id] = session_id if session_id.present? && task.agent_session_id.blank?
        updates[:agent_session_key] = session_key if session_key.present? && task.agent_session_key.blank?

        provided_files = params[:output_files].presence || params[:files].presence
        extracted_from_findings = task.extract_output_files_from_findings(findings)

        candidate_files = task.normalized_output_files(provided_files)
        candidate_files = extracted_from_findings if candidate_files.blank?

        if task.agent_session_id.present? || updates[:agent_session_id].present?
          candidate_files += task.extract_output_files_from_transcript_commit
        end

        merged_files = task.normalized_output_files((task.output_files || []) + candidate_files)
        updates[:output_files] = merged_files if merged_files.any?

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

      def updated_description(current_description, findings)
        marker = "## Agent Output"
        output_block = "#{marker}\n\n#{findings}"

        if current_description.start_with?(marker)
          # Replace existing top "Agent Output" section, preserving remaining description.
          if current_description.include?("\n\n---\n\n")
            _old_output, rest = current_description.split("\n\n---\n\n", 2)
            return "#{output_block}\n\n---\n\n#{rest}"
          end

          return output_block
        end

        if current_description.blank?
          output_block
        else
          "#{output_block}\n\n---\n\n#{current_description}"
        end
      end
    end
  end
end
