
module Api
  module V1
    class TasksController < BaseController
      # agent_log is public (no auth required) - secured by task lookup
      skip_before_action :authenticate_api_token, only: [ :agent_log, :session_health ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :agent_complete, :claim, :unclaim, :assign, :unassign, :generate_followup, :create_followup, :move, :enhance_followup, :handoff, :link_session, :report_rate_limit, :revalidate, :start_validation, :run_debate, :complete_review, :file, :add_dependency, :remove_dependency, :dependencies ]
      before_action :set_task_for_agent_log, only: [ :agent_log, :session_health ]

      private

      def set_task_for_agent_log
        # Public lookup - anyone with the task ID can see agent activity
        # This is safe because it only shows agent logs, not sensitive data
        @task = Task.find_by(id: params[:id])
        unless @task
          render json: { error: "Task not found" }, status: :not_found
        end
      end

      public

      # GET /api/v1/tasks/:id/agent_log - get agent transcript for this task
      # Returns parsed messages from the OpenClaw session transcript
      # Supports ?since=N param to get only messages after line N (for polling efficiency)
      def agent_log
        # Lazy resolution: try to resolve session_id from session_key if missing
        if @task.agent_session_id.blank? && @task.agent_session_key.present?
          resolved_id = resolve_session_id_from_key(@task.agent_session_key, @task)
          if resolved_id.present?
            @task.update_column(:agent_session_id, resolved_id)
            Rails.logger.info("[agent_log] Lazy-resolved session_id=#{resolved_id} for task #{@task.id}")
          end
        end

        unless @task.agent_session_id.present?
          # No session ID, but check for agent output in description as fallback
          if @task.description.present? && @task.description.include?("## Agent Output")
            output_match = @task.description.match(/## Agent Output.*?\n(.*)/m)
            if output_match
              extracted_output = output_match[1].strip
              render json: {
                messages: [{ role: "assistant", content: [{ type: "text", text: extracted_output }] }],
                total_lines: 1,
                has_session: true,
                fallback: true,
                task_status: @task.status
              }
              return
            end
          end
          # Also check for output_files - synthesize a summary message
          if @task.output_files.present? && @task.output_files.any?
            file_list = @task.output_files.map { |f| "📄 #{f}" }.join("\n")
            render json: {
              messages: [{ role: "assistant", content: [{ type: "text", text: "Agent produced #{@task.output_files.size} file(s):\n#{file_list}" }] }],
              total_lines: 1,
              has_session: true,
              fallback: true,
              task_status: @task.status
            }
            return
          end
          render json: { messages: [], total_lines: 0, has_session: false, task_status: @task.status }
          return
        end

        # Sanitize session ID to prevent path traversal attacks
        session_id = @task.agent_session_id.to_s
        unless session_id.match?(/\A[a-zA-Z0-9_\-]+\z/)
          render json: { messages: [], total_lines: 0, has_session: false, error: "Invalid session ID format" }
          return
        end

        # Build path to the transcript file
        transcript_path = File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl")

        # Fallback: look for archived transcript (.jsonl.deleted.*)
        unless File.exist?(transcript_path)
          archived = Dir.glob(File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl.deleted.*")).first
          transcript_path = archived if archived
        end

        unless File.exist?(transcript_path.to_s)
          # Fallback: extract "## Agent Output" from task description if present
          if @task.description.present? && @task.description.include?("## Agent Output")
            output_match = @task.description.match(/## Agent Output.*?\n(.*)/m)
            if output_match
              extracted_output = output_match[1].strip
              render json: {
                messages: [{ role: "assistant", content: [{ type: "text", text: extracted_output }] }],
                total_lines: 1,
                has_session: true,
                fallback: true
              }
              return
            end
          end
          render json: { messages: [], total_lines: 0, has_session: true, error: "Transcript file not found" }
          return
        end

        # Read and parse the JSONL file
        since_line = params[:since].to_i
        messages = []
        line_number = 0

        File.foreach(transcript_path) do |line|
          line_number += 1
          next if line_number <= since_line

          begin
            data = JSON.parse(line.strip)
            # Only include message types that are interesting for the UI
            if data["type"] == "message"
              msg = data["message"]
              next unless msg

              parsed = {
                id: data["id"],
                line: line_number,
                timestamp: data["timestamp"],
                role: msg["role"]
              }

              # Extract content based on type
              content = msg["content"]
              if content.is_a?(Array)
                # Handle array content (assistant messages with thinking/text/toolCall)
                parsed[:content] = content.map do |item|
                  case item["type"]
                  when "text"
                    { type: "text", text: item["text"]&.slice(0, 2000) }
                  when "thinking"
                    { type: "thinking", text: item["thinking"]&.slice(0, 500) }
                  when "toolCall"
                    { type: "tool_call", name: item["name"], id: item["id"] }
                  else
                    { type: item["type"] || "unknown" }
                  end
                end
              elsif content.is_a?(String)
                # Handle string content (user messages)
                parsed[:content] = [{ type: "text", text: content.slice(0, 2000) }]
              end

              # For tool results, extract useful info
              if msg["role"] == "toolResult"
                parsed[:tool_call_id] = msg["toolCallId"]
                parsed[:tool_name] = msg["toolName"]
                tool_content = msg["content"]
                if tool_content.is_a?(Array) && tool_content.first
                  text = tool_content.first["text"]
                  parsed[:content] = [{ type: "tool_result", text: text&.slice(0, 1000) }]
                end
              end

              messages << parsed
            end
          rescue JSON::ParserError
            # Skip malformed lines
            next
          end
        end

        render json: {
          messages: messages,
          total_lines: line_number,
          since: since_line,
          has_session: true,
          task_status: @task.status
        }
      end

      # GET /api/v1/tasks/errored_count - count of errored tasks for badge
      def errored_count
        count = current_user.tasks.errored.count
        render json: { count: count }
      end

      # GET /api/v1/tasks/recurring - list recurring task templates
      def recurring
        @tasks = current_user.tasks
          .recurring_templates
          .order(created_at: :desc)

        render json: @tasks.map { |task| task_json(task) }
      end

      # GET /api/v1/tasks/next - get next task for agent to work on
      # Returns highest priority unclaimed task in "up_next" status
      # Returns 204 No Content if no tasks available or user has auto_mode disabled
      def next
        # Check if user has agent auto mode enabled
        unless current_user.agent_auto_mode?
          head :no_content
          return
        end

        @task = current_user.tasks
          .where(status: :up_next, blocked: false, agent_claimed_at: nil)
          .order(priority: :desc, position: :asc)
          .first

        if @task
          render json: task_json(@task)
        else
          head :no_content
        end
      end

      # GET /api/v1/tasks/pending_attention - tasks needing agent attention
      # Returns tasks that are in "in_progress" and were claimed by agent
      def pending_attention
        unless current_user.agent_auto_mode?
          render json: []
          return
        end

        # Tasks in progress that agent claimed
        @tasks = current_user.tasks
          .where(status: :in_progress)
          .where.not(agent_claimed_at: nil)

        render json: @tasks.map { |task| task_json(task) }
      end

      # PATCH /api/v1/tasks/:id/claim - agent claims a task
      # Accepts optional session_id/session_key to link session at claim time
      def claim
        set_task_activity_info(@task)

        # Auto-link session if provided
        sid = params[:session_id] || params[:agent_session_id]
        skey = params[:session_key] || params[:agent_session_key]
        updates = { agent_claimed_at: Time.current, status: :in_progress }
        updates[:agent_session_id] = sid if sid.present?
        updates[:agent_session_key] = skey if skey.present?

        @task.update!(updates)

        # Create notification for agent claim
        Notification.create_for_agent_claim(@task)

        # Broadcast agent activity started via WebSocket
        AgentActivityChannel.broadcast_status(@task.id, "in_progress", {
          agent_claimed: true,
          session_linked: sid.present?
        })

        render json: task_json(@task)
      end

      # PATCH /api/v1/tasks/:id/unclaim - agent releases a task
      def unclaim
        set_task_activity_info(@task)
        @task.update!(agent_claimed_at: nil)
        render json: task_json(@task)
      end

      # PATCH /api/v1/tasks/:id/assign - assign task to agent
      def assign
        set_task_activity_info(@task)
        @task.update!(assigned_to_agent: true, assigned_at: Time.current)
        render json: task_json(@task)
      end

      # PATCH /api/v1/tasks/:id/unassign - unassign task from agent
      def unassign
        set_task_activity_info(@task)
        @task.update!(assigned_to_agent: false, assigned_at: nil)
        render json: task_json(@task)
      end

      # GET /api/v1/tasks/:id/session_health - check agent session health for continuation
      def session_health
        unless @task.agent_session_key.present?
          render json: { alive: false, context_percent: 0, recommendation: "fresh", reason: "no_session" }
          return
        end

        # Mock the OpenClaw session status API for now
        # In the future, this will call: GET {gateway_url}/api/sessions/{session_key}/status
        # The real API returns: { alive: bool, usage: { inputTokens, outputTokens, cacheReadTokens, cacheCreationTokens } }

        # For now, use stored context_usage_percent or simulate based on session age
        context_percent = @task.context_usage_percent || simulate_context_usage(@task)
        alive = context_percent < 100  # Session is "alive" if under 100%

        threshold = current_user&.context_threshold_percent || 70  # Default 70% for public access
        recommendation = if !alive
          "fresh"
        elsif context_percent > threshold
          "fresh"
        else
          "continue"
        end

        render json: {
          alive: alive,
          context_percent: context_percent,
          recommendation: recommendation,
          threshold: threshold,
          session_key: @task.agent_session_key
        }
      end

      # POST /api/v1/tasks/:id/generate_followup - generate AI suggestion for followup
      def generate_followup
        suggestion = @task.generate_followup_suggestion
        @task.update!(suggested_followup: suggestion)
        render json: { suggested_followup: suggestion, task: task_json(@task) }
      end

      # POST /api/v1/tasks/:id/enhance_followup - enhance draft description with AI
      def enhance_followup
        draft = params[:draft]
        enhanced = AiSuggestionService.new(@task.user).enhance_description(@task, draft)
        render json: { enhanced: enhanced || draft }
      end

      # POST /api/v1/tasks/:id/handoff - handoff task to a different model
      def handoff
        new_model = params[:model]
        unless Task::MODELS.include?(new_model)
          render json: { error: "Invalid model. Must be one of: #{Task::MODELS.join(', ')}" }, status: :unprocessable_entity
          return
        end

        include_transcript = ActiveModel::Type::Boolean.new.cast(params[:include_transcript])

        # Build handoff context for orchestrator
        context = {
          task_id: @task.id,
          task_name: @task.name,
          task_description: @task.description,
          previous_model: @task.model,
          new_model: new_model,
          error_message: @task.error_message,
          error_at: @task.error_at&.iso8601,
          include_transcript: include_transcript
        }

        # Fetch transcript snippet if requested
        if include_transcript && @task.agent_session_id.present?
          transcript_path = File.expand_path("~/.openclaw/agents/main/sessions/#{@task.agent_session_id}.jsonl")
          if File.exist?(transcript_path)
            # Get last 50 lines of transcript for context
            lines = File.readlines(transcript_path).last(50)
            context[:transcript_preview] = lines.join
          end
        end

        set_task_activity_info(@task)
        @task.activity_note = "Handoff from #{@task.model || 'default'} to #{new_model}"
        @task.handoff!(new_model: new_model, include_transcript: include_transcript)

        render json: {
          task: task_json(@task),
          handoff_context: context
        }
      end

      # POST /api/v1/tasks/spawn_ready
      # Creates a task ready for agent spawn (in_progress, assigned_to_agent: true)
      # Returns the task ID for the orchestrator to spawn an agent
      # Supports auto-fallback: if requested model is rate-limited, uses next available
      def spawn_ready
        @task = current_user.tasks.new(spawn_ready_params)
        @task.status = :in_progress
        @task.assigned_to_agent = true
        # Auto-detect board based on task name if not specified
        @task.board_id ||= detect_board_for_task(@task.name, current_user)&.id || current_user.boards.first&.id
        set_task_activity_info(@task)

        # Auto-fallback: check if requested model is available, otherwise use fallback
        # Set default model if not specified
        @task.model ||= Task::DEFAULT_MODEL
        requested_model = @task.model
        fallback_note = nil

        if requested_model.present?
          # Clear any expired limits first
          ModelLimit.clear_expired_limits!

          actual_model, fallback_note = ModelLimit.best_available_model(current_user, requested_model)

          if actual_model != requested_model
            @task.model = actual_model
            # Prepend fallback note to description
            if fallback_note.present?
              @task.description = "#{fallback_note}\n\n---\n\n#{@task.description}"
            end
          end
        end

        if @task.save
          response = task_json(@task)
          response[:fallback_used] = fallback_note.present?
          response[:fallback_note] = fallback_note
          response[:requested_model] = requested_model
          render json: response, status: :created
        else
          render json: { errors: @task.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/tasks/:id/link_session
      # Links OpenClaw session info to a task after spawning
      # Accepts both `session_id`/`session_key` and `agent_session_id`/`agent_session_key` aliases
      def link_session
        sid = params[:session_id] || params[:agent_session_id]
        skey = params[:session_key] || params[:agent_session_key]

        # Try to resolve session_id from session_key if only key is provided
        if sid.blank? && skey.present?
          sid = resolve_session_id_from_key(skey, @task)
          Rails.logger.info("[link_session] Resolved session_id=#{sid} for task #{@task.id}") if sid.present?
        end

        @task.agent_session_id = sid if sid.present?
        @task.agent_session_key = skey if skey.present?
        set_task_activity_info(@task)

        if @task.save
          # Broadcast session linked - clients can start watching for activity
          AgentActivityChannel.broadcast_status(@task.id, @task.status, {
            session_linked: true,
            has_session: @task.agent_session_id.present?
          })

          render json: { success: true, task_id: @task.id, task: task_json(@task) }
        else
          render json: { errors: @task.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/tasks/:id/create_followup - create a followup task
      def create_followup
        set_task_activity_info(@task)
        followup_name = params[:followup_name] || params.dig(:task, :followup_name) || "Follow up: #{@task.name}"
        followup_description = params[:followup_description] || params.dig(:task, :followup_description)

        followup = @task.create_followup_task!(
          followup_name: followup_name,
          followup_description: followup_description
        )

        # Auto-complete parent task when follow-up is created
        @task.update!(status: "done", completed: true, completed_at: Time.current)

        render json: { followup: task_json(followup), source_task: task_json(@task) }, status: :created
      end

      # PATCH /api/v1/tasks/:id/move - move task to a different status column
      def move
        new_status = params[:status]
        unless Task.statuses.key?(new_status)
          render json: { error: "Invalid status: #{new_status}" }, status: :unprocessable_entity
          return
        end

        set_task_activity_info(@task)
        @task.update!(status: new_status)
        render json: task_json(@task)
      end

      # GET /api/v1/tasks - all tasks for current user
      def index
        @tasks = current_user.tasks

        # Filter by board
        if params[:board_id].present?
          @tasks = @tasks.where(board_id: params[:board_id])
        end

        # Apply filters
        if params[:status].present? && Task.statuses.key?(params[:status])
          @tasks = @tasks.where(status: params[:status])
        end

        if params[:blocked].present?
          blocked = ActiveModel::Type::Boolean.new.cast(params[:blocked])
          @tasks = @tasks.where(blocked: blocked)
        end

        if params[:tag].present?
          @tasks = @tasks.where("? = ANY(tags)", params[:tag])
        end

        if params[:completed].present?
          completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
          @tasks = @tasks.where(completed: completed)
        end

        if params[:priority].present? && Task.priorities.key?(params[:priority])
          @tasks = @tasks.where(priority: params[:priority])
        end

        # Filter by agent assignment
        if params[:assigned].present?
          assigned = ActiveModel::Type::Boolean.new.cast(params[:assigned])
          @tasks = @tasks.where(assigned_to_agent: assigned)
        end

        # Filter by nightly (Nightbeat) tasks
        if params[:nightly].present?
          nightly = ActiveModel::Type::Boolean.new.cast(params[:nightly])
          @tasks = @tasks.where(nightly: nightly)
        end

        # Order by assigned_at for assigned tasks, otherwise by status then position
        if params[:assigned].present? && ActiveModel::Type::Boolean.new.cast(params[:assigned])
          @tasks = @tasks.order(assigned_at: :asc)
        else
          @tasks = @tasks.order(status: :asc, position: :asc)
        end

        render json: @tasks.map { |task| task_json(task) }
      end

      # POST /api/v1/tasks
      def create
        # Assign to specified board or default to user's first board
        board_id = params.dig(:task, :board_id) || params[:board_id]
        board = if board_id.present?
          current_user.boards.find(board_id)
        else
          current_user.boards.first || current_user.boards.create!(name: "Personal", icon: "📋", color: "gray")
        end

        @task = board.tasks.new(task_params)
        @task.user = current_user
        set_task_activity_info(@task)

        # Apply template if specified
        if params.dig(:task, :template_slug).present?
          template = TaskTemplate.find_for_user(params[:task][:template_slug], current_user)
          if template
            task_name = @task.name || ""
            template_attrs = template.to_task_attributes(task_name)
            @task.assign_attributes(template_attrs.except(:name))
            @task.name = template_attrs[:name] if task_name.present?
          end
        end

        if @task.save
          render json: task_json(@task), status: :created
        else
          render json: { error: @task.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/tasks/:id
      def show
        render json: task_json(@task)
      end

      # PATCH /api/v1/tasks/:id
      def update
        set_task_activity_info(@task)
        if @task.update(task_params)
          # Try to resolve session_id from session_key if key was set but id is missing
          if @task.agent_session_id.blank? && @task.agent_session_key.present?
            resolved_id = resolve_session_id_from_key(@task.agent_session_key, @task)
            if resolved_id.present?
              @task.update_column(:agent_session_id, resolved_id)
              Rails.logger.info("[update] Resolved session_id=#{resolved_id} for task #{@task.id}")
            end
          end

          # Auto-resolve: if task still has no session_id and description was just updated with agent output,
          # scan recent transcripts for this task's ID
          if @task.agent_session_id.blank? && @task.description&.include?("## Agent Output")
            resolved_id = scan_transcripts_for_task(@task.id)
            if resolved_id.present?
              @task.update_column(:agent_session_id, resolved_id)
              Rails.logger.info("[update] Auto-resolved session_id=#{resolved_id} for task #{@task.id} from transcript scan")
            end
          end

          render json: task_json(@task.reload)
        else
          render json: { error: @task.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tasks/:id
      def destroy
        @task.destroy!
        head :no_content
      end

      # PATCH /api/v1/tasks/:id/complete
      # Toggles task between done and inbox status
      def complete
        set_task_activity_info(@task)
        new_status = @task.status == "done" ? "inbox" : "done"
        @task.update!(status: new_status)
        render json: task_json(@task)
      end

      # POST /api/v1/tasks/:id/agent_complete
      # Called by OpenClaw when agent finishes working on a task
      # Appends agent output to description, moves to in_review
      # If validation_command is present, runs it and updates validation_status
      # Accepts optional `files` array of file paths produced by the agent
      # Accepts optional `session_id`/`session_key` to auto-link session (last line of defense)
      def agent_complete
        set_task_activity_info(@task)

        # Auto-link session if provided and not already set
        sid = params[:session_id] || params[:agent_session_id]
        skey = params[:session_key] || params[:agent_session_key]

        # If we have a session_key but no session_id, try to resolve it from transcript files
        if skey.present? && sid.blank?
          sid = resolve_session_id_from_key(skey, @task)
        end

        @task.agent_session_id = sid if sid.present? && @task.agent_session_id.blank?
        @task.agent_session_key = skey if skey.present? && @task.agent_session_key.blank?

        # Last resort: scan transcript files for task ID
        if @task.agent_session_id.blank?
          scanned_id = scan_transcripts_for_task(@task.id)
          if scanned_id.present?
            @task.agent_session_id = scanned_id
            Rails.logger.info("[agent_complete] Auto-resolved session_id=#{scanned_id} for task #{@task.id} from transcript scan")
          end
        end

        # Accept ANY reasonable field name for output text
        output_text = params[:output].presence || params[:description].presence ||
                      params[:summary].presence || params[:result].presence ||
                      params[:text].presence || params[:message].presence ||
                      params[:content].presence

        # Accept ANY reasonable field name for files
        raw_files = params[:output_files].presence || params[:files].presence ||
                    params[:created_files].presence || params[:changed_files].presence ||
                    params[:modified_files].presence

        Rails.logger.info("agent_complete for task #{@task.id}: output=#{output_text.present?} (#{output_text&.length || 0} chars), files=#{Array(raw_files).size}, params_keys=#{params.keys.join(',')}")

        if output_text.blank? && raw_files.blank?
          Rails.logger.warn("agent_complete called with no output for task #{@task.id}, params: #{params.except(:controller, :action, :id).to_unsafe_h}")
        end

        updates = { status: params[:status].presence || :in_review }

        if output_text.present?
          # Append agent output to description (avoid duplicating if already present)
          new_description = @task.description.to_s
          unless new_description.include?("## Agent Output")
            new_description += "\n\n## Agent Output\n"
          end
          new_description += output_text
          updates[:description] = new_description
        end

        # Store output files if provided (already extracted above from multiple field names)
        if raw_files.present?
          files = Array(raw_files).map(&:to_s).reject(&:blank?)
          updates[:output_files] = ((@task.output_files || []) + files).uniq
        end

        # Set completed_at if not already set
        updates[:completed_at] = Time.current unless @task.completed_at.present?

        # Clear agent claim since work is done
        updates[:agent_claimed_at] = nil

        @task.update!(updates)

        # Record token usage if provided (Foxhound analytics)
        record_token_usage(@task, params)

        # Broadcast agent activity completion via WebSocket
        AgentActivityChannel.broadcast_status(@task.id, "in_review", {
          output_present: output_text.present?,
          files_count: (@task.output_files || []).size
        })

        # Run validation command if present (legacy method for pre-set commands)
        if @task.validation_command.present?
          ValidationRunnerService.new(@task).call
        else
          # Enqueue auto-validation job (generates command from output_files, runs async)
          AutoValidationJob.perform_later(@task.id)
        end

        render json: task_json(@task)
      end

      # GET /api/v1/tasks/:id/file?path=docs/PROJECT_REVIEW.md
      # Returns file content for a task's output file
      # Validates path to prevent directory traversal
      def file
        path = params[:path].to_s
        if path.blank?
          render json: { error: "Path parameter required" }, status: :bad_request
          return
        end

        # Determine roots for path resolution
        project_root = Rails.root.to_s
        workspace_root = File.expand_path("~/.openclaw/workspace")

        # Resolve the file path - try multiple locations for relative paths
        if Pathname.new(path).absolute?
          full_path = File.expand_path(path)
        else
          candidates = [
            File.expand_path(File.join(workspace_root, path)),
            File.expand_path(File.join(project_root, path)),
          ]
          board_project_path = @task.board.try(:project_path)
          if board_project_path.present?
            candidates.unshift(File.expand_path(File.join(board_project_path, path)))
          end
          full_path = candidates.find { |p| File.exist?(p) && File.file?(p) }
          full_path ||= candidates.first
        end

        # Security: prevent directory traversal - must be in allowed dirs or output_files
        allowed_dirs = [project_root, workspace_root]
        board_project_path ||= @task.board.try(:project_path)
        allowed_dirs << board_project_path if board_project_path.present?
        in_output_files = (@task.output_files || []).include?(path)
        in_allowed_dir = allowed_dirs.any? { |dir| full_path.start_with?(dir) }

        unless in_output_files || in_allowed_dir
          render json: { error: "Access denied: path outside project directory" }, status: :forbidden
          return
        end

        unless File.exist?(full_path) && File.file?(full_path)
          render json: { error: "File not found: #{path}" }, status: :not_found
          return
        end

        # Read and return file content
        content = File.read(full_path, encoding: "UTF-8")
        render json: {
          path: path,
          content: content,
          size: File.size(full_path),
          extension: File.extname(full_path).delete(".")
        }
      end

      # POST /api/v1/tasks/:id/revalidate
      # Re-run the validation command for a task
      def revalidate
        unless @task.validation_command.present?
          render json: { error: "No validation command configured" }, status: :unprocessable_entity
          return
        end

        set_task_activity_info(@task)
        ValidationRunnerService.new(@task).call

        render json: {
          task: task_json(@task),
          validation_status: @task.validation_status,
          validation_output: @task.validation_output
        }
      end

      # POST /api/v1/tasks/:id/start_validation
      # Start a validation review with a command
      def start_validation
        command = params[:command].presence || @task.validation_command
        unless command.present?
          render json: { error: "No validation command specified" }, status: :unprocessable_entity
          return
        end

        set_task_activity_info(@task)
        @task.start_review!(type: "command", config: { command: command })
        @task.update!(validation_command: command)

        # Run validation in background
        RunValidationJob.perform_later(@task.id)

        render json: {
          task: task_json(@task),
          review_status: @task.review_status,
          message: "Validation started"
        }
      end

      # POST /api/v1/tasks/:id/run_debate
      # Start a debate review
      def run_debate
        style = params[:style] || "quick"
        focus = params[:focus]
        models = Array(params[:models]).reject(&:blank?)
        models = %w[gemini claude glm] if models.empty?

        set_task_activity_info(@task)
        @task.start_review!(
          type: "debate",
          config: {
            style: style,
            focus: focus,
            models: models
          }
        )

        # Run debate in background
        RunDebateJob.perform_later(@task.id)

        render json: {
          task: task_json(@task),
          review_status: @task.review_status,
          message: "Debate review started"
        }
      end

      # POST /api/v1/tasks/:id/complete_review
      # Complete a review with status and result (called by background job or external process)
      def complete_review
        status = params[:status]
        result = params[:result] || {}

        unless %w[passed failed].include?(status)
          render json: { error: "Status must be 'passed' or 'failed'" }, status: :unprocessable_entity
          return
        end

        set_task_activity_info(@task)
        @task.complete_review!(status: status, result: result)

        # Create notification for review result
        Notification.create_for_review(@task, passed: status == "passed")

        render json: {
          task: task_json(@task),
          review_status: @task.review_status,
          review_result: @task.review_result
        }
      end

      # GET /api/v1/tasks/:id/dependencies
      # Returns the task's dependencies and dependents
      def dependencies
        render json: {
          dependencies: @task.dependencies.map { |t| dependency_json(t) },
          dependents: @task.dependents.map { |t| dependency_json(t) },
          blocked: @task.blocked?,
          blocking_tasks: @task.blocking_tasks.map { |t| dependency_json(t) }
        }
      end

      # POST /api/v1/tasks/:id/add_dependency
      # Add a dependency to this task (this task depends on another)
      def add_dependency
        depends_on_id = params[:depends_on_id]
        
        unless depends_on_id.present?
          render json: { error: "depends_on_id parameter required" }, status: :bad_request
          return
        end

        depends_on = current_user.tasks.find_by(id: depends_on_id)
        
        unless depends_on
          render json: { error: "Task #{depends_on_id} not found" }, status: :not_found
          return
        end

        begin
          dependency = @task.task_dependencies.create!(depends_on: depends_on)
          set_task_activity_info(@task)
          @task.activity_note = "Added dependency on ##{depends_on.id}: #{depends_on.name.truncate(30)}"
          @task.touch  # Trigger activity recording

          render json: {
            success: true,
            dependency: {
              id: dependency.id,
              task_id: @task.id,
              depends_on_id: depends_on.id,
              depends_on: dependency_json(depends_on)
            },
            blocked: @task.reload.blocked?
          }
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tasks/:id/remove_dependency
      # Remove a dependency from this task
      def remove_dependency
        depends_on_id = params[:depends_on_id]
        
        unless depends_on_id.present?
          render json: { error: "depends_on_id parameter required" }, status: :bad_request
          return
        end

        dependency = @task.task_dependencies.find_by(depends_on_id: depends_on_id)
        
        unless dependency
          render json: { error: "Dependency not found" }, status: :not_found
          return
        end

        depends_on = dependency.depends_on
        dependency.destroy!
        
        set_task_activity_info(@task)
        @task.activity_note = "Removed dependency on ##{depends_on.id}: #{depends_on.name.truncate(30)}"
        @task.touch  # Trigger activity recording

        render json: {
          success: true,
          blocked: @task.reload.blocked?
        }
      end

      # POST /api/v1/tasks/:id/report_rate_limit
      # Called when a task encounters a rate limit error for its model
      # Records the limit and optionally triggers auto-fallback
      def report_rate_limit
        model_name = params[:model_name] || @task.model
        error_message = params[:error_message] || "Rate limit exceeded"
        resets_at = params[:resets_at].present? ? Time.parse(params[:resets_at]) : nil

        unless model_name.present?
          render json: { error: "Model name required" }, status: :unprocessable_entity
          return
        end

        # Record the rate limit
        limit = ModelLimit.record_limit!(current_user, model_name, error_message)
        limit.update!(resets_at: resets_at) if resets_at.present?

        # Update task error state
        set_task_activity_info(@task)
        @task.set_error!(error_message)

        # Create notification for error
        Notification.create_for_error(@task, error_message)

        # Auto-fallback if enabled
        fallback_note = nil
        if params[:auto_fallback] != false
          new_model, fallback_note = ModelLimit.best_available_model(current_user, model_name)

          if new_model != model_name
            @task.handoff!(new_model: new_model, include_transcript: false)
            @task.activity_note = fallback_note
            @task.save!
          end
        end

        render json: {
          task: task_json(@task),
          model_limit: {
            model: limit.model_name,
            limited: limit.limited,
            resets_at: limit.resets_at&.iso8601,
            resets_in: limit.time_until_reset
          },
          fallback_used: fallback_note.present?,
          fallback_note: fallback_note,
          new_model: @task.model
        }
      end

      private

      def set_task
        @task = current_user.tasks.find(params[:id])
      end

      # Record token usage from agent_complete params (Foxhound analytics)
      # Accepts tokens directly in params OR extracts from session transcript
      def record_token_usage(task, params)
        input_tokens = params[:input_tokens].to_i
        output_tokens = params[:output_tokens].to_i
        model = params[:token_model] || task.model

        # If tokens not provided directly, try to extract from session transcript
        if input_tokens == 0 && output_tokens == 0
          session_tokens = extract_tokens_from_session(task)
          if session_tokens
            input_tokens = session_tokens[:input_tokens]
            output_tokens = session_tokens[:output_tokens]
            model ||= session_tokens[:model]
          end
        end

        # Only record if we have meaningful data
        return if input_tokens == 0 && output_tokens == 0

        TokenUsage.record_from_session(
          task: task,
          session_data: {
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            model: model
          },
          session_key: task.agent_session_key
        )
      rescue => e
        Rails.logger.error("[Foxhound] Failed to record token usage for task #{task.id}: #{e.message}")
      end

      # Extract token counts from an OpenClaw session transcript
      def extract_tokens_from_session(task)
        return nil unless task.agent_session_id.present?

        session_id = task.agent_session_id.to_s
        return nil unless session_id.match?(/\A[a-zA-Z0-9_\-]+\z/)

        transcript_path = File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl")
        return nil unless File.exist?(transcript_path)

        input_tokens = 0
        output_tokens = 0
        model = nil

        File.foreach(transcript_path) do |line|
          next if line.blank?
          begin
            entry = JSON.parse(line)
            if entry["usage"].is_a?(Hash)
              input_tokens += entry["usage"]["input_tokens"].to_i
              output_tokens += entry["usage"]["output_tokens"].to_i
            end
            # Try to capture model from entries
            model ||= entry["model"] if entry["model"].present?
          rescue JSON::ParserError
            next
          end
        end

        return nil if input_tokens == 0 && output_tokens == 0

        { input_tokens: input_tokens, output_tokens: output_tokens, model: model }
      rescue => e
        Rails.logger.error("[Foxhound] Failed to extract tokens from session: #{e.message}")
        nil
      end

      # Resolve session_id (UUID) from session_key by scanning transcript files
      # The OpenClaw gateway stores transcripts as {sessionId}.jsonl
      # NOTE: The session_key UUID is NOT in the file, but the Task ID IS!
      # Subagent prompts start with "## Task #ID:" which we can match
      def resolve_session_id_from_key(session_key, task = nil)
        sessions_dir = File.expand_path("~/.openclaw/agents/main/sessions")
        return nil unless Dir.exist?(sessions_dir)
        return nil if session_key.blank?

        # Get task_id from param or from the task's session_key context
        task_id = task&.id || @task&.id
        return nil unless task_id.present?

        # Build search patterns - the task prompt contains "Task #ID:" near the start
        task_pattern = "Task ##{task_id}:"
        cutoff_time = 7.days.ago  # Search up to 7 days back for session files

        # Search active .jsonl files (most recent first for faster hits)
        files = Dir.glob(File.join(sessions_dir, "*.jsonl")).sort_by { |f| -File.mtime(f).to_i }

        files.each do |file|
          # Skip old files for performance
          next if File.mtime(file) < cutoff_time

          # Read first 10 lines - the task prompt is in the first user message
          first_lines = []
          File.foreach(file).with_index do |line, idx|
            break if idx >= 10
            first_lines << line
          end
          content_sample = first_lines.join

          # Check if this file is for our task
          if content_sample.include?(task_pattern)
            session_id = File.basename(file, ".jsonl")
            Rails.logger.info("[resolve_session_id] Found session_id=#{session_id} for task #{task_id} in #{File.basename(file)}")
            return session_id
          end
        end

        # Also check archived files (with .deleted. suffix) if not found
        archived_files = Dir.glob(File.join(sessions_dir, "*.jsonl.deleted.*")).sort_by { |f| -File.mtime(f).to_i }

        archived_files.each do |file|
          next if File.mtime(file) < cutoff_time

          first_lines = []
          File.foreach(file).with_index do |line, idx|
            break if idx >= 10
            first_lines << line
          end
          content_sample = first_lines.join

          if content_sample.include?(task_pattern)
            # Extract session_id from filename like "abc123.jsonl.deleted.2026-02-06..."
            session_id = File.basename(file).sub(/\.jsonl\.deleted\..+$/, "")
            Rails.logger.info("[resolve_session_id] Found session_id=#{session_id} (archived) for task #{task_id}")
            return session_id
          end
        end

        Rails.logger.info("[resolve_session_id] No session file found for task #{task_id}")
        nil
      rescue => e
        Rails.logger.warn "resolve_session_id_from_key error: #{e.message}"
        nil
      end

      # Scan recent transcript files for references to a task ID
      # Used as a last-resort fallback when agent_session_key is not available
      # Agents include the task ID in their curl commands and prompt context
      def scan_transcripts_for_task(task_id)
        sessions_dir = File.expand_path("~/.openclaw/agents/main/sessions")
        return nil unless Dir.exist?(sessions_dir)

        # Look at the 30 most recent .jsonl files
        files = Dir.glob(File.join(sessions_dir, "*.jsonl"))
          .sort_by { |f| -File.mtime(f).to_i }
          .first(30)

        # Search patterns - agents have the task ID in their prompt
        patterns = ["tasks/#{task_id}", "Task ##{task_id}", "task_id.*#{task_id}", "Task ID: #{task_id}"]

        files.each do |file|
          # Read first 5KB of the file (task prompt is at the top)
          sample = File.read(file, 5000) rescue next

          if patterns.any? { |p| sample.include?(p) }
            session_id = File.basename(file, ".jsonl")
            # Don't return if this session_id is already linked to another task
            if Task.where(agent_session_id: session_id).where.not(id: task_id).none?
              Rails.logger.info("[scan_transcripts] Found session_id=#{session_id} for task #{task_id}")
              return session_id
            end
          end
        end

        nil
      rescue => e
        Rails.logger.warn "[scan_transcripts] Error scanning for task #{task_id}: #{e.message}"
        nil
      end

      def set_task_activity_info(task)
        task.activity_source = "api"
        task.actor_name = request.headers["X-Agent-Name"]
        task.actor_emoji = request.headers["X-Agent-Emoji"]
        task.activity_note = params[:activity_note] || params.dig(:task, :activity_note)
      end

      def task_params
        params.require(:task).permit(:name, :description, :priority, :due_date, :status, :blocked, :board_id, :model, :recurring, :recurrence_rule, :recurrence_time, :agent_session_id, :agent_session_key, :context_usage_percent, :nightly, :nightly_delay_hours, :error_message, :error_at, :retry_count, :validation_command, :review_type, :review_status, :agent_persona_id, tags: [], output_files: [], review_config: {}, review_result: {})
      end

      # Validation command execution delegated to ValidationRunnerService

      def spawn_ready_params
        params.require(:task).permit(:name, :description, :model, :priority, :board_id, tags: [])
      end

      # Auto-detect which board a task belongs to based on its name
      # Uses board's auto_claim_prefix field for configurable matching
      # Used by spawn_ready to route tasks to the appropriate board
      def detect_board_for_task(name, user)
        return nil if name.blank?

        # First, check boards with auto_claim_prefix configured
        user.boards.where.not(auto_claim_prefix: [nil, ""]).find_each do |board|
          if name.downcase.include?(board.auto_claim_prefix.downcase)
            return board
          end
        end

        # Fallback: find first non-aggregator board
        user.boards.find_by(is_aggregator: false) || user.boards.first
      end

      # Simulate context usage based on session age (mock for now)
      # Real implementation will call OpenClaw API
      def simulate_context_usage(task)
        return 0 unless task.agent_claimed_at.present?

        # Simulate: older sessions have more context used
        hours_active = ((Time.current - task.agent_claimed_at) / 1.hour).to_i
        # Assume roughly 10-15% context per hour of active work
        simulated = [ hours_active * rand(10..15), 95 ].min
        simulated
      end

      def dependency_json(task)
        {
          id: task.id,
          name: task.name,
          status: task.status,
          done: task.status.in?(%w[done archived]),
          blocked: task.blocked?
        }
      end

      def task_json(task)
        {
          id: task.id,
          name: task.name,
          description: task.description,
          priority: task.priority,
          status: task.status,
          blocked: task.blocked?,  # Use method instead of column
          tags: task.tags || [],
          completed: task.completed,
          completed_at: task.completed_at&.iso8601,
          due_date: task.due_date&.iso8601,
          position: task.position,
          assigned_to_agent: task.assigned_to_agent,
          assigned_at: task.assigned_at&.iso8601,
          agent_claimed_at: task.agent_claimed_at&.iso8601,
          board_id: task.board_id,
          model: task.model,
          recurring: task.recurring,
          recurrence_rule: task.recurrence_rule,
          recurrence_time: task.recurrence_time&.strftime("%H:%M"),
          next_recurrence_at: task.next_recurrence_at&.iso8601,
          parent_task_id: task.parent_task_id,
          agent_session_id: task.agent_session_id,
          agent_session_key: task.agent_session_key,
          context_usage_percent: task.context_usage_percent,
          nightly: task.nightly,
          nightly_delay_hours: task.nightly_delay_hours,
          error_message: task.error_message,
          error_at: task.error_at&.iso8601,
          retry_count: task.retry_count,
          suggested_followup: task.suggested_followup,
          followup_task_id: task.followup_task_id,
          validation_command: task.validation_command,
          validation_status: task.validation_status,
          validation_output: task.validation_output,
          review_type: task.review_type,
          review_status: task.review_status,
          review_config: task.review_config,
          review_result: task.review_result,
          agent_persona_id: task.agent_persona_id,
          agent_persona: task.agent_persona ? { id: task.agent_persona.id, name: task.agent_persona.name, emoji: task.agent_persona.emoji } : nil,
          output_files: task.output_files || [],
          dependencies: task.dependencies.map { |t| dependency_json(t) },
          dependents: task.dependents.map { |t| dependency_json(t) },
          blocking_tasks: task.blocking_tasks.map { |t| dependency_json(t) },
          url: "https://clawdeck.io/boards/#{task.board_id}/tasks/#{task.id}",
          created_at: task.created_at.iso8601,
          updated_at: task.updated_at.iso8601
        }
      end
    end
  end
end
