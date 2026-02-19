# frozen_string_literal: true

# Concern for agent lifecycle operations on tasks:
# claim, unclaim, requeue, assign, unassign, link_session, spawn_ready, session_health
#
# Extracted from Api::V1::TasksController to reduce its size (-270 lines).
# Requires the host controller to define:
#   - current_user
#   - set_task_activity_info(task)
#   - broadcast_kanban_update(task, old_status:, new_status:)
#   - task_json(task)
module Api
  module TaskAgentLifecycle
    extend ActiveSupport::Concern

    # PATCH /api/v1/tasks/:id/claim - agent claims a task
    def claim
      old_status = @task.status
      set_task_activity_info(@task)

      sid = params[:session_id] || params[:agent_session_id]
      skey = params[:session_key] || params[:agent_session_key]

      now = Time.current

      Task.transaction do
        @task.lock!

        unless @task.runner_leases.active.exists?
          RunnerLease.create_for_task!(
            task: @task,
            agent_name: @task.user&.agent_name,
            source: "api_claim"
          )
        end

        updates = { agent_claimed_at: now, status: :in_progress }
        updates[:agent_session_id] = sid if sid.present?
        updates[:agent_session_key] = skey if skey.present?
        updates[:pipeline_stage] = "executing" if @task.pipeline_enabled? && @task.pipeline_stage == "routed"

        @task.update!(updates)
      end

      Notification.create_for_agent_claim(@task)

      AgentActivityChannel.broadcast_status(@task.id, "in_progress", {
        agent_claimed: true,
        session_linked: sid.present?
      })

      broadcast_kanban_update(@task, old_status: old_status, new_status: @task.status)

      render json: task_json(@task)
    end

    # PATCH /api/v1/tasks/:id/unclaim - agent releases a task
    def unclaim
      old_status = @task.status
      set_task_activity_info(@task)
      Task.transaction do
        @task.lock!
        @task.runner_leases.where(released_at: nil).update_all(released_at: Time.current)
        @task.update!(agent_claimed_at: nil, status: :up_next)
      end

      if @task.pipeline_enabled?
        target = (@task.routed_model.present? && @task.compiled_prompt.present?) ? "routed" : "unstarted"
        sync_pipeline_stage_for_task!(@task, target_stage: target, source: "api#unclaim")
      end

      broadcast_kanban_update(@task, old_status: old_status, new_status: @task.status)
      render json: task_json(@task)
    end

    # POST /api/v1/tasks/:id/requeue - requeue SAME card back to Up Next
    def requeue
      old_status = @task.status
      set_task_activity_info(@task)

      Task.transaction do
        @task.lock!
        @task.runner_leases.where(released_at: nil).update_all(released_at: Time.current)
        @task.update!(
          status: :up_next,
          agent_claimed_at: nil,
          agent_session_id: nil,
          agent_session_key: nil
        )
      end

      if @task.pipeline_enabled?
        target = (@task.routed_model.present? && @task.compiled_prompt.present?) ? "routed" : "unstarted"
        sync_pipeline_stage_for_task!(@task, target_stage: target, source: "api#requeue")
      end

      broadcast_kanban_update(@task, old_status: old_status, new_status: @task.status)
      render json: task_json(@task)
    end

    # PATCH /api/v1/tasks/:id/assign - assign task to agent
    def assign
      old_status = @task.status
      set_task_activity_info(@task)
      @task.update!(assigned_to_agent: true, assigned_at: Time.current)
      broadcast_kanban_update(@task, old_status: old_status, new_status: @task.status)
      render json: task_json(@task)
    end

    # PATCH /api/v1/tasks/:id/unassign - unassign task from agent
    def unassign
      old_status = @task.status
      set_task_activity_info(@task)
      @task.update!(assigned_to_agent: false, assigned_at: nil)
      broadcast_kanban_update(@task, old_status: old_status, new_status: @task.status)
      render json: task_json(@task)
    end

    # GET /api/v1/tasks/:id/session_health - check agent session health
    def session_health
      unless @task.agent_session_key.present?
        render json: { alive: false, context_percent: 0, recommendation: "fresh", reason: "no_session" }
        return
      end

      context_percent = @task.context_usage_percent || simulate_context_usage(@task)
      alive = context_percent < 100

      threshold = current_user&.context_threshold_percent || 70
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

    # POST /api/v1/tasks/:id/link_session
    def link_session
      sid = params[:session_id] || params[:agent_session_id]
      skey = params[:session_key] || params[:agent_session_key]

      if sid.blank? && skey.present?
        sid = resolve_session_id_from_key(skey, @task)
        Rails.logger.info("[link_session] Resolved session_id=#{sid} for task #{@task.id}") if sid.present?
      end

      @task.agent_session_id = sid if sid.present?
      @task.agent_session_key = skey if skey.present?
      set_task_activity_info(@task)

      if @task.save
        AgentActivityChannel.broadcast_status(@task.id, @task.status, {
          session_linked: true,
          has_session: @task.agent_session_id.present?
        })

        render json: { success: true, task_id: @task.id, task: task_json(@task) }
      else
        render json: { errors: @task.errors }, status: :unprocessable_entity
      end
    end

    # POST /api/v1/tasks/spawn_ready - create + claim + start task in one call
    def spawn_ready
      @task = current_user.tasks.new(spawn_ready_params)

      @task.status = :up_next
      @task.assigned_to_agent = true
      @task.board_id ||= detect_board_for_task(@task.name, current_user)&.id || current_user.boards.order(position: :asc).first&.id
      set_task_activity_info(@task)
      OriginRoutingService.apply!(@task, params: params, headers: request.headers)

      @task.model ||= Task::DEFAULT_MODEL
      requested_model = @task.model
      fallback_note = nil

      if requested_model.present?
        ModelLimit.clear_expired_limits!

        actual_model, fallback_note = ModelLimit.best_available_model(current_user, requested_model)

        if actual_model != requested_model
          @task.model = actual_model
          if fallback_note.present?
            @task.description = "#{fallback_note}\n\n---\n\n#{@task.description}"
          end
        end
      end

      if @task.save
        now = Time.current

        RunnerLease.create_for_task!(
          task: @task,
          agent_name: current_user.agent_name,
          source: "spawn_ready"
        )

        @task.update!(status: :in_progress, agent_claimed_at: now)
        if @task.pipeline_enabled? && @task.pipeline_stage == "routed"
          sync_pipeline_stage_for_task!(@task, target_stage: "executing", source: "api#spawn_ready")
        end

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

    private

    def spawn_ready_params
      params.require(:task).permit(:name, :description, :model, :priority, :board_id, :origin_chat_id, :origin_thread_id, :origin_session_id, :origin_session_key, tags: [])
    end

    # Auto-detect which board a task belongs to based on its name
    def detect_board_for_task(name, user)
      return nil if name.blank?

      user.boards.where.not(auto_claim_prefix: [nil, ""]).find_each do |board|
        if name.downcase.include?(board.auto_claim_prefix.downcase)
          return board
        end
      end

      user.boards.find_by(is_aggregator: false) || user.boards.order(position: :asc).first
    end

    def sync_pipeline_stage_for_task!(task, target_stage:, source:)
      return if target_stage.blank? || task.pipeline_stage.to_s == target_stage

      log = Array(task.pipeline_log)
      log << {
        stage: "pipeline_sync",
        from: task.pipeline_stage,
        to: target_stage,
        source: source,
        at: Time.current.iso8601
      }

      task.update_columns(pipeline_stage: target_stage, pipeline_log: log, updated_at: Time.current)
      task.reload
    rescue StandardError => e
      Rails.logger.warn("[TaskAgentLifecycle] Pipeline stage sync failed task_id=#{task.id}: #{e.message}")
    end

    # Simulate context usage based on session age (mock for now)
    def simulate_context_usage(task)
      return 0 unless task.agent_claimed_at.present?

      hours_active = ((Time.current - task.agent_claimed_at) / 1.hour).to_i
      [hours_active * rand(10..15), 95].min
    end
  end
end
