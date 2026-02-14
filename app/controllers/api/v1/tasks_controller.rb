# frozen_string_literal: true


module Api
  module V1
    class TasksController < BaseController
      include OutputRenderable
      include Api::TaskDependencyManagement
      include Api::TaskPipelineManagement
      include Api::TaskAgentLifecycle
      include Api::TaskValidationManagement
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :agent_complete, :claim, :unclaim, :assign, :unassign, :generate_followup, :create_followup, :move, :enhance_followup, :handoff, :link_session, :report_rate_limit, :revalidate, :start_validation, :run_debate, :complete_review, :recover_output, :file, :add_dependency, :remove_dependency, :dependencies, :agent_log, :session_health ]

      # GET /api/v1/tasks/:id/agent_log - get agent transcript for this task
      # Returns parsed messages from the OpenClaw session transcript
      # Supports ?since=N param to get only messages after line N (for polling efficiency)
      def agent_log
        resolver = method(:resolve_session_id_from_key)
        result = AgentLogService.new(@task, since: params[:since].to_i, session_resolver: resolver).call

        render json: {
          messages: result.messages,
          total_lines: result.total_lines,
          since: result.since,
          has_session: result.has_session,
          fallback: result.fallback,
          error: result.error,
          task_status: result.task_status
        }.compact
      end

      TASK_JSON_INCLUDES = {
        task_dependencies: :depends_on,
        inverse_dependencies: :task,
        agent_persona: {}
      }.freeze

      # GET /api/v1/tasks/errored_count - count of errored tasks for badge
      def errored_count
        count = current_user.tasks.errored.count
        render json: { count: count }
      end

      # GET /api/v1/tasks/recurring - list recurring task templates
      def recurring
        @tasks = current_user.tasks
          .recurring_templates
          .includes(TASK_JSON_INCLUDES)
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
          .includes(TASK_JSON_INCLUDES)
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
          .includes(TASK_JSON_INCLUDES)
          .where(status: :in_progress)
          .where.not(agent_claimed_at: nil)

        render json: @tasks.map { |task| task_json(task) }
      end

      # claim, unclaim, requeue, assign, unassign, session_health, link_session, spawn_ready
      # → Api::TaskAgentLifecycle concern

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
          transcript_path = TranscriptParser.transcript_path(@task.agent_session_id)
          if transcript_path
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

        # Create as queued first; we'll attach a lease and then promote to in_progress.
        # This keeps the in_progress ⇔ active lease invariant truthful.
        @task.status = :up_next
        @task.assigned_to_agent = true
        # Auto-detect board based on task name if not specified
        @task.board_id ||= detect_board_for_task(@task.name, current_user)&.id || current_user.boards.order(position: :asc).first&.id
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
          now = Time.current

          RunnerLease.create!(
            task: @task,
            agent_name: current_user.agent_name,
            lease_token: SecureRandom.hex(24),
            source: "spawn_ready",
            started_at: now,
            last_heartbeat_at: now,
            expires_at: now + RunnerLease::LEASE_DURATION
          )

          @task.update!(status: :in_progress, agent_claimed_at: now)

          Rails.logger.info(
            "[spawn_ready] task_id=#{@task.id} requested_model=#{requested_model.inspect} " \
            "applied_model=#{@task.model.inspect} openclaw_spawn_model=#{@task.openclaw_spawn_model.inspect} " \
            "fallback_used=#{fallback_note.present?}"
          )

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
        if @task.update(status: new_status)
          render json: task_json(@task)
        else
          render json: {
            error: @task.errors.full_messages.join(", "),
            errors: @task.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/tasks/export
      # Params: format (json|csv), board_id, statuses[], tag, include_archived
      def export
        exporter = TaskExportService.new(
          current_user,
          board_id: params[:board_id],
          statuses: params[:statuses],
          tag: params[:tag],
          include_archived: ActiveModel::Type::Boolean.new.cast(params[:include_archived])
        )

        case params[:format]&.downcase
        when "csv"
          send_data exporter.to_csv, filename: "tasks-#{Date.current.iso8601}.csv", type: "text/csv"
        else
          render json: exporter.to_json, content_type: "application/json"
        end
      end

      # POST /api/v1/tasks/import
      # Body: JSON export format { tasks: [...] }
      def import
        board = current_user.boards.find(params[:board_id])
        json_body = request.body.read(5.megabytes)

        if json_body.blank?
          return render json: { error: "Empty request body" }, status: :bad_request
        end

        importer = TaskImportService.new(current_user, board)
        result = importer.import_json(json_body)

        render json: {
          imported: result.imported,
          skipped: result.skipped,
          errors: result.errors,
          task_ids: result.tasks.map(&:id)
        }, status: result.imported > 0 ? :created : :unprocessable_entity
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

        # Pagination
        page = [(params[:page] || 1).to_i, 1].max
        per_page = [(params[:per_page] || 50).to_i.clamp(1, 100), 100].min
        total = @tasks.count
        @tasks = @tasks.offset((page - 1) * per_page).limit(per_page)

        # Add pagination headers
        response.set_header("X-Total-Count", total.to_s)
        response.set_header("X-Page", page.to_s)
        response.set_header("X-Per-Page", per_page.to_s)
        if page * per_page < total
          response.set_header("X-Next-Page", (page + 1).to_s)
        end

        @tasks = @tasks.includes(TASK_JSON_INCLUDES)

        render json: @tasks.map { |task| task_json(task) }
      end

      # POST /api/v1/tasks
      def create
        # Assign to specified board or default to user's first board
        board_id = params.dig(:task, :board_id) || params[:board_id]
        board = if board_id.present?
          current_user.boards.find(board_id)
        else
          current_user.boards.order(position: :asc).first || current_user.boards.create!(name: "Personal", icon: "📋", color: "gray")
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

        # Safety: agent-created tasks with assigned_to_agent land in inbox
        # so they don't get auto-pulled without human approval.
        if @task.assigned_to_agent? && @task.status == "up_next" && request_from_agent?
          @task.status = :inbox
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
        old_status = @task.status
        set_task_activity_info(@task)
        if @task.update(task_params)
          status_changed = @task.saved_change_to_status?
          status_before = @task.status_before_last_save

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

          # Real-time UI update for agent-driven changes (Bearer token calls).
          if status_changed
            broadcast_kanban_update(@task, old_status: status_before, new_status: @task.status)
          else
            broadcast_kanban_update(@task, old_status: old_status, new_status: @task.status)
          end

          render json: task_json(@task.reload)
        else
          render json: {
            error: @task.errors.full_messages.join(", "),
            errors: @task.errors.full_messages
          }, status: :unprocessable_entity
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

        # Delegate to AgentCompletionService (DRY — same logic used in HooksController)
        result = AgentCompletionService.new(
          @task,
          params,
          session_resolver: method(:resolve_session_id_from_key),
          transcript_scanner: method(:scan_transcripts_for_task)
        ).call

        if result.success?
          render json: task_json(@task.reload)
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/tasks/:id/recover_output
      # Recover missing Agent Output from the linked OpenClaw transcript
      def recover_output
        if @task.agent_session_id.blank?
          render json: { error: "No transcript found. Use manual edit." }, status: :unprocessable_entity
          return
        end

        session_id = @task.agent_session_id.to_s
        unless session_id.match?(/\A[a-zA-Z0-9_\-]+\z/)
          render json: { error: "No transcript found. Use manual edit." }, status: :unprocessable_entity
          return
        end

        transcript_path = TranscriptParser.transcript_path(session_id)

        unless transcript_path
          render json: { error: "No transcript found. Use manual edit." }, status: :unprocessable_entity
          return
        end

        recovered_text = extract_recoverable_agent_output(transcript_path)
        if recovered_text.blank?
          render json: { error: "No transcript found. Use manual edit." }, status: :unprocessable_entity
          return
        end

        set_task_activity_info(@task)

        existing = @task.description.to_s
        marker = "## Agent Output"
        new_description = if existing.include?(marker)
          existing.sub(/## Agent Output\s*\n*/m, "## Agent Output\n\n#{recovered_text}\n\n")
        else
          ["#{marker}\n\n#{recovered_text}", existing].reject(&:blank?).join("\n\n")
        end

        @task.update!(description: new_description)

        render json: task_json(@task.reload)
      end

      # GET /api/v1/tasks/:id/file?path=docs/PROJECT_REVIEW.md
      # Returns file content for a task's output file
      # SECURITY FIX #495: Strict path validation - only relative paths within allowed dirs
      def file
        path = params[:path].to_s
        if path.blank?
          render json: { error: "Path parameter required" }, status: :bad_request
          return
        end

        # Build allowed directories list
        project_root = Rails.root.to_s
        storage_root = Rails.root.join("storage").to_s
        allowed_dirs = [project_root, storage_root]

        # Include board's project path if configured
        board_project_path = @task.board.try(:project_path)
        if board_project_path.present?
          allowed_dirs.unshift(File.expand_path(board_project_path))
        end

        # Use secure path resolution (rejects absolute paths, ~/, dotfiles, traversal)
        full_path = resolve_safe_path(path, allowed_dirs: allowed_dirs)

        unless full_path
          render json: { error: "Access denied: invalid path" }, status: :forbidden
          return
        end

        unless File.exist?(full_path) && File.file?(full_path)
          render json: { error: "File not found: #{path}" }, status: :not_found
          return
        end

        # Security: enforce size limit to prevent memory exhaustion
        file_size = File.size(full_path)
        max_file_size = 2.megabytes
        if file_size > max_file_size
          render json: { error: "File too large (#{file_size} bytes, max #{max_file_size})", path: path, size: file_size }, status: :unprocessable_entity
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
        # Debate review is not yet implemented — return early
        render json: {
          error: "Debate review is not yet implemented. Coming soon.",
          not_implemented: true
        }, status: :service_unavailable
        return

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

      # POST /api/v1/tasks/:id/route_pipeline
      # route_pipeline, pipeline_info → Api::TaskPipelineManagement concern
      # dependencies, add_dependency, remove_dependency → Api::TaskDependencyManagement concern

      # POST /api/v1/tasks/:id/report_rate_limit
      # Called when a task encounters a rate limit error for its model
      # Records the limit and optionally triggers auto-fallback
      def report_rate_limit
        model_name = params[:model_name] || @task.model
        error_message = params[:error_message] || "Rate limit exceeded"
        resets_at = if params[:resets_at].present?
          begin
            Time.parse(params[:resets_at])
          rescue ArgumentError
            nil
          end
        end

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

      def extract_recoverable_agent_output(transcript_path)
        TranscriptParser.extract_summary(transcript_path)
      rescue StandardError => e
        Rails.logger.warn("[recover_output] Failed parsing transcript for task #{@task&.id}: #{e.message}")
        nil
      end

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
      rescue StandardError => e
        Rails.logger.error("[Foxhound] Failed to record token usage for task #{task.id}: #{e.message}")
      end

      # Extract token counts from an OpenClaw session transcript
      def extract_tokens_from_session(task)
        return nil unless task.agent_session_id.present?

        transcript_file = TranscriptParser.transcript_path(task.agent_session_id)
        return nil unless transcript_file

        input_tokens = 0
        output_tokens = 0
        model = nil

        TranscriptParser.each_entry(transcript_file) do |entry, _line_num|
          if entry["usage"].is_a?(Hash)
            input_tokens += entry["usage"]["input_tokens"].to_i
            output_tokens += entry["usage"]["output_tokens"].to_i
          end
          model ||= entry["model"] if entry["model"].present?
        end

        return nil if input_tokens == 0 && output_tokens == 0

        { input_tokens: input_tokens, output_tokens: output_tokens, model: model }
      rescue StandardError => e
        Rails.logger.error("[Foxhound] Failed to extract tokens from session: #{e.message}")
        nil
      end

      # Resolve session_id (UUID) from session_key by scanning transcript files
      # The OpenClaw gateway stores transcripts as {sessionId}.jsonl
      # NOTE: The session_key UUID is NOT in the file, but the Task ID IS!
      # Subagent prompts start with "## Task #ID:" which we can match
      def resolve_session_id_from_key(session_key, task = nil)
        sessions_dir = TranscriptParser::SESSIONS_DIR
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
      rescue StandardError => e
        Rails.logger.warn "resolve_session_id_from_key error: #{e.message}"
        nil
      end

      # Scan recent transcript files for references to a task ID
      # Used as a last-resort fallback when agent_session_key is not available
      # Agents include the task ID in their curl commands and prompt context
      def scan_transcripts_for_task(task_id)
        sessions_dir = TranscriptParser::SESSIONS_DIR
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
      rescue StandardError => e
        Rails.logger.warn "[scan_transcripts] Error scanning for task #{task_id}: #{e.message}"
        nil
      end

      # Returns true when the request comes from an agent (X-Agent-Name header present)
      def request_from_agent?
        request.headers["X-Agent-Name"].present?
      end

      def set_task_activity_info(task)
        task.activity_source = "api"
        task.actor_name = request.headers["X-Agent-Name"]
        task.actor_emoji = request.headers["X-Agent-Emoji"]
        task.activity_note = params[:activity_note] || params.dig(:task, :activity_note)
      end

      def broadcast_kanban_update(task, old_status: nil, new_status: nil, action: "update")
        # Only broadcast for token-authenticated calls (the agent/orchestrator).
        # Browser UI actions already return Turbo Streams and should not trigger a full refresh.
        return unless extract_token_from_header.present?

        KanbanChannel.broadcast_refresh(
          task.board_id,
          task_id: task.id,
          action: action,
          old_status: old_status,
          new_status: new_status
        )
      rescue StandardError => e
        Rails.logger.warn("[Api::V1::TasksController] Kanban broadcast failed task_id=#{task.id}: #{e.class}: #{e.message}")
      end

      def task_params
        params.require(:task).permit(:name, :description, :priority, :due_date, :status, :blocked, :board_id, :model, :pipeline_stage, :recurring, :recurrence_rule, :recurrence_time, :agent_session_id, :agent_session_key, :context_usage_percent, :nightly, :nightly_delay_hours, :error_message, :error_at, :retry_count, :validation_command, :review_type, :review_status, :agent_persona_id, :origin_chat_id, :origin_thread_id, tags: [], output_files: [], review_config: {}, review_result: {})
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
        user.boards.find_by(is_aggregator: false) || user.boards.order(position: :asc).first
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
        TaskSerializer.dependency_json(task)
      end

      def task_json(task)
        TaskSerializer.new(task).as_json
      end
    end
  end
end
