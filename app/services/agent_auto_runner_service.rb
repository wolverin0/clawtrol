# frozen_string_literal: true

class AgentAutoRunnerService
  NO_FAKE_IN_PROGRESS_GRACE = 10.minutes
  LEASE_STALE_AFTER = 10.minutes
  ZOMBIE_STALE_AFTER = 30.minutes
  SPAWN_COOLDOWN = 1.minute
  ZOMBIE_NOTIFY_COOLDOWN = 60.minutes
  FAILURE_COOLDOWN = 5.minutes
  FAILURE_LIMIT = 3

  NIGHT_TZ = "America/Argentina/Buenos_Aires"

  def initialize(logger: Rails.logger, cache: Rails.cache, openclaw_webhook_service: OpenclawWebhookService, openclaw_gateway_client: nil)
    @logger = logger
    @cache = cache
    @openclaw_webhook_service = openclaw_webhook_service
    @openclaw_gateway_client = openclaw_gateway_client
  end

  def run!
    stats = {
      users_considered: 0,
      users_woken: 0,
      tasks_demoted: 0,
      zombie_tasks: 0,
      pipeline_processed: 0
    }

    User.where(agent_auto_mode: true).find_each do |user|
      next unless openclaw_configured?(user)

      stats[:users_considered] += 1

      stats[:tasks_demoted] += demote_expired_or_missing_leases!(user)
      stats[:zombie_tasks] += notify_zombies_if_any!(user)

      next if agent_currently_working?(user)

      # Optional pipeline pre-routing only in pipeline assist mode.
      if pipeline_assist_enabled_for?(user)
        stats[:pipeline_processed] += process_pipeline_tasks!(user)
      end

      if wake_if_work_available!(user)
        stats[:users_woken] += 1
      end
    end

    @logger.info("[AgentAutoRunner] finished stats=#{stats.inspect}")
    stats
  end

  private

  def openclaw_configured?(user)
    hooks_token = user.respond_to?(:openclaw_hooks_token) ? user.openclaw_hooks_token : nil
    user.openclaw_gateway_url.present? && (hooks_token.present? || user.openclaw_gateway_token.present?)
  end

  def pipeline_assist_enabled_for?(user)
    user.respond_to?(:pipeline_assist_mode?) && user.pipeline_assist_mode?
  end

  def agent_currently_working?(user)
    RunnerLease.active.joins(:task).where(tasks: { user_id: user.id, status: Task.statuses[:in_progress] }).exists?
  end

  def runnable_up_next_task_for(user)
    scope = user.tasks
      .where(status: :up_next, blocked: false, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)
      .where(assigned_to_agent: true)
      .where(auto_pull_blocked: false)
      .where("auto_pull_last_error_at IS NULL OR auto_pull_last_error_at < ?", Time.current - FAILURE_COOLDOWN)
      .where.not(recurring: true, parent_task_id: nil)

    tasks = scope.order(priority: :desc, position: :asc, assigned_to_agent: :desc, assigned_at: :asc).to_a
    tasks.find { |t| eligible_for_time_window?(t) }
  end

  # Pipeline: process tasks that need pipeline advancement
  # Simplified: skip triage, go straight to context compilation + routing
  def process_pipeline_tasks!(user)
    count = 0
    tasks = user.tasks.where(pipeline_enabled: true, status: :up_next)
                      .where(pipeline_stage: [nil, "", "unstarted", "triaged", "context_ready"])
                      .limit(5)

    tasks.find_each do |task|
      Task.transaction(requires_new: true) do
        if task.model.blank?
          task.update_columns(model: Task::DEFAULT_MODEL)
        end

        Pipeline::Orchestrator.new(task, user: user).process_to_completion!

        count += 1
      end
    rescue StandardError => e
      @logger.warn("[AgentAutoRunner] pipeline processing failed task_id=#{task.id} err=#{e.class}: #{e.message}")
    end

    count
  end

  def wake_if_work_available!(user)
    task = runnable_up_next_task_for(user)
    return false unless task

    cache_key = "agent_auto_runner:last_wake:user:#{user.id}"
    return false if @cache.read(cache_key).present?

    Notification.create_deduped!(
      user: user,
      task: task,
      event_type: "auto_pull_ready",
      message: "Auto-pull ready: ##{task.id} #{task.name.truncate(60)}"
    )

    begin
      if pipeline_assist_enabled_for?(user) && task.pipeline_ready?
        @openclaw_webhook_service.new(user).notify_auto_pull_ready_with_pipeline(task)
      else
        @openclaw_webhook_service.new(user).notify_auto_pull_ready(task)
      end
    rescue StandardError => e
      @logger.warn("[AgentAutoRunner] wake failed user_id=#{user.id} task_id=#{task.id} err=#{e.class}: #{e.message}")
    end

    @cache.write(cache_key, Time.current.to_i, expires_in: SPAWN_COOLDOWN)

    @logger.info("[AgentAutoRunner] wake sent user_id=#{user.id} task_id=#{task.id} pipeline_ready=#{task.pipeline_ready?} orchestration_mode=#{user.orchestration_mode}")
    true
  rescue StandardError => e
    @logger.error("[AgentAutoRunner] auto-pull wake failed user_id=#{user.id} task_id=#{task&.id} err=#{e.class}: #{e.message}")

    begin
      Notification.create_deduped!(
        user: user,
        task: task,
        event_type: "auto_pull_error",
        message: "Auto-pull wake failed: #{e.class}: #{e.message}".truncate(250)
      )
    rescue StandardError
    end

    false
  end

  def eligible_for_time_window?(task)
    return true unless task.nightly?

    now = Time.current.in_time_zone(NIGHT_TZ)
    start_hour = Rails.configuration.x.auto_runner.nightly_start_hour
    end_hour = Rails.configuration.x.auto_runner.nightly_end_hour

    in_window = if start_hour < end_hour
      now.hour >= start_hour && now.hour < end_hour
    else
      now.hour >= start_hour || now.hour < end_hour
    end

    return false unless in_window

    delay_hours = task.nightly_delay_hours.to_i
    return true if delay_hours <= 0

    night_start_date = now.hour >= start_hour ? now.to_date : (now.to_date - 1.day)
    night_start = Time.find_zone!(NIGHT_TZ).local(night_start_date.year, night_start_date.month, night_start_date.day, start_hour, 0, 0)

    now >= (night_start + delay_hours.hours)
  end

  def demote_expired_or_missing_leases!(user)
    count = 0

    RunnerLease.expired.joins(:task).where(tasks: { user_id: user.id, status: Task.statuses[:in_progress] }).find_each do |lease|
      task = lease.task
      old_status = task.status

      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "🤖"
      task.activity_note = "Auto-demoted: Runner Lease expired (last hb #{lease.last_heartbeat_at&.iso8601})"

      lease.release!
      task.update!(status: :up_next, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)

      KanbanChannel.broadcast_refresh(
        task.board_id,
        task_id: task.id,
        action: "update",
        old_status: old_status,
        new_status: task.status
      )

      Notification.create_deduped!(
        user: user,
        task: task,
        event_type: "runner_lease_expired",
        message: "Guardrail: demoted expired RUNNING task back to Up Next: #{task.name.truncate(60)}"
      )

      count += 1
      @logger.warn("[AgentAutoRunner] demoted expired lease task_id=#{task.id} lease_id=#{lease.id}")
    rescue StandardError => e
      @logger.error("[AgentAutoRunner] failed to demote expired lease_id=#{lease&.id} task_id=#{task&.id} err=#{e.class}: #{e.message}")
    end

    cutoff = Time.current - NO_FAKE_IN_PROGRESS_GRACE
    active_lease_task_ids = RunnerLease.active.where(task_id: user.tasks.select(:id)).select(:task_id)

    tasks = user.tasks
      .where(status: :in_progress, assigned_to_agent: true, agent_session_id: nil)
      .where("tasks.updated_at < ?", cutoff)
      .where.not(id: active_lease_task_ids)

    tasks.find_each do |task|
      old_status = task.status
      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "🤖"
      task.activity_note = "Auto-demoted: in_progress without Runner Lease for > #{NO_FAKE_IN_PROGRESS_GRACE.inspect}"

      task.update!(status: :up_next, agent_claimed_at: nil)

      KanbanChannel.broadcast_refresh(
        task.board_id,
        task_id: task.id,
        action: "update",
        old_status: old_status,
        new_status: task.status
      )

      Notification.create_deduped!(
        user: user,
        task: task,
        event_type: "runner_lease_missing",
        message: "Guardrail: demoted task without lease back to Up Next: #{task.name.truncate(60)}"
      )

      count += 1
      @logger.warn("[AgentAutoRunner] demoted missing-lease task_id=#{task.id}")
    rescue StandardError => e
      @logger.error("[AgentAutoRunner] failed to demote missing-lease task_id=#{task.id} err=#{e.class}: #{e.message}")
    end

    count
  end

  def notify_zombies_if_any!(user)
    cutoff = Time.current - ZOMBIE_STALE_AFTER

    zombie_count = user.tasks
      .where(status: :in_progress)
      .where.not(agent_claimed_at: nil)
      .where("updated_at < ?", cutoff)
      .count

    return 0 if zombie_count.zero?

    cache_key = "agent_auto_runner:last_zombie_notify:user:#{user.id}"
    return zombie_count if @cache.read(cache_key).present?

    Notification.create_deduped!(
      user: user,
      event_type: "zombie_detected",
      message: "Zombie KPI: #{zombie_count} in-progress task(s) look stale (> #{ZOMBIE_STALE_AFTER.inspect} without updates)"
    )

    @cache.write(cache_key, Time.current.to_i, expires_in: ZOMBIE_NOTIFY_COOLDOWN)

    @logger.warn("[AgentAutoRunner] zombie KPI user_id=#{user.id} count=#{zombie_count}")

    zombie_count
  end
end
