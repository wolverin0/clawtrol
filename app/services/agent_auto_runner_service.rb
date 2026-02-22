# frozen_string_literal: true

class AgentAutoRunnerService
  NO_FAKE_IN_PROGRESS_GRACE = 10.minutes
  ZOMBIE_STALE_AFTER = 30.minutes
  SPAWN_COOLDOWN = 1.minute
  ZOMBIE_NOTIFY_COOLDOWN = 60.minutes

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
      tasks_woken: 0,
      tasks_demoted: 0,
      zombie_tasks: 0,
      pipeline_processed: 0,
      queue_skip_reasons: Hash.new(0),
      queue_summaries_sent: 0
    }

    User.where(agent_auto_mode: true).find_each do |user|
      next unless openclaw_configured?(user)

      stats[:users_considered] += 1

      stats[:tasks_demoted] += demote_expired_or_missing_leases!(user)
      stats[:zombie_tasks] += notify_zombies_if_any!(user)

      selector = QueueOrchestrationSelector.new(user, now: Time.current, logger: @logger)
      plan = selector.plan
      plan.skip_reasons.each { |reason, amount| stats[:queue_skip_reasons][reason] += amount.to_i }

woke = 0
if plan.tasks.any?
  woke = wake_tasks!(user, plan.tasks)
  if woke.positive?
    stats[:users_woken] += 1
    stats[:tasks_woken] += woke
  end
end

if maybe_send_queue_summary!(user: user, selector: selector, plan: plan, tasks_woken: woke)
  stats[:queue_summaries_sent] += 1
end
    end

    stats[:queue_skip_reasons] = stats[:queue_skip_reasons].to_h
    @logger.info("[AgentAutoRunner] finished stats=#{stats.inspect}")
    stats
  end

  private

  def openclaw_configured?(user)
    hooks_token = user.respond_to?(:openclaw_hooks_token) ? user.openclaw_hooks_token : nil
    user.openclaw_gateway_url.present? && (hooks_token.present? || user.openclaw_gateway_token.present?)
  end

  # Pipeline: process tasks that need pipeline advancement
  # Simplified: skip triage, go straight to context compilation + routing
  def process_pipeline_tasks!(user)
    return 0 # pipeline removed
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

  def wake_tasks!(user, tasks)
    woke = 0
    tasks.each do |task|
      next unless wake_task!(user, task)

      woke += 1
    end
    woke
  end

  def wake_task!(user, task)
    cache_key = "agent_auto_runner:last_wake:user:#{user.id}:task:#{task.id}"
    return false if @cache.read(cache_key).present?

    Notification.create_deduped!(
      user: user,
      task: task,
      event_type: "auto_pull_ready",
      message: "Auto-pull ready: ##{task.id} #{task.name.truncate(60)}"
    )

    begin
      service = @openclaw_webhook_service.new(user)
      if task.pipeline_ready?
        service.notify_auto_pull_ready_with_pipeline(task)
      else
        service.notify_auto_pull_ready(task)
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

def maybe_send_queue_summary!(user:, selector:, plan:, tasks_woken:)
  interval_minutes = Rails.configuration.x.auto_runner.summary_interval_minutes.to_i
  interval = [interval_minutes, 1].max.minutes

  cache_key = "agent_auto_runner:last_summary:user:#{user.id}"
  return false if @cache.read(cache_key).present?

  metrics = selector.metrics
  queue_depth = metrics[:queue_depth].to_i
  active = metrics[:active_in_progress].to_i
  return false if queue_depth.zero? && active.zero? && tasks_woken.to_i.zero?

  top_skips = plan.skip_reasons
    .sort_by { |(_reason, count)| -count.to_i }
    .first(3)
    .map { |(reason, count)| "#{reason}=#{count}" }

  mode = metrics[:in_night_window] ? "night" : "day"
  summary = "Queue summary: mode=#{mode} max=#{metrics[:max_concurrent]} active=#{active} queue=#{queue_depth} slots=#{metrics[:available_slots]} woken_now=#{tasks_woken}"
  summary += " skip={#{top_skips.join(",")}}" if top_skips.any?

  @openclaw_webhook_service.new(user).notify_runner_summary(summary)

  bucket = (Time.current.to_i / interval.to_i)
  Notification.create_deduped!(
    user: user,
    event_type: "auto_runner",
    message: summary,
    event_id: "auto_runner_summary:user:#{user.id}:#{bucket}",
    ttl: interval
  )

  @cache.write(cache_key, Time.current.to_i, expires_in: interval)
  true
rescue StandardError => e
  @logger.warn("[AgentAutoRunner] queue summary failed user_id=#{user.id} err=#{e.class}: #{e.message}")
  false
end


  def demote_expired_or_missing_leases!(user)
    count = 0

    stale_cutoff = Time.current - Rails.configuration.x.auto_runner.stale_heartbeat_minutes.to_i.minutes
    stale_leases = RunnerLease.active
      .joins(:task)
      .where(tasks: { user_id: user.id, status: Task.statuses[:in_progress] })
      .where("runner_leases.last_heartbeat_at < ?", stale_cutoff)

    stale_leases.find_each do |lease|
      task = lease.task
      old_status = task.status

      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "??"
      task.activity_note = "Auto-demoted: stale lease heartbeat (last hb #{lease.last_heartbeat_at&.iso8601})"

      demote_to_up_next!(task, release_lease: lease)
      broadcast_update(task, old_status: old_status)

      if HeartbeatAlertGuard.allow?(key: "task:#{task.id}:lease_stale", state: lease.last_heartbeat_at&.to_i)
        Notification.create_deduped!(
          user: user,
          task: task,
          event_type: "runner_lease_expired",
          message: "Guardrail: demoted stale RUNNING task back to Up Next: #{task.name.truncate(60)}",
          event_id: "runner_lease_stale:task:#{task.id}:lease:#{lease.id}"
        )
      end

      count += 1
      @logger.warn("[AgentAutoRunner] demoted stale lease task_id=#{task.id} lease_id=#{lease.id}")
    rescue StandardError => e
      @logger.error("[AgentAutoRunner] failed stale-lease demotion lease_id=#{lease&.id} task_id=#{task&.id} err=#{e.class}: #{e.message}")
    end

    RunnerLease.expired.joins(:task).where(tasks: { user_id: user.id, status: Task.statuses[:in_progress] }).find_each do |lease|
      task = lease.task
      old_status = task.status

      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "??"
      task.activity_note = "Auto-demoted: Runner Lease expired (last hb #{lease.last_heartbeat_at&.iso8601})"

      demote_to_up_next!(task, release_lease: lease)
      broadcast_update(task, old_status: old_status)

      if HeartbeatAlertGuard.allow?(key: "task:#{task.id}:lease_expired", state: lease.last_heartbeat_at&.to_i)
        Notification.create_deduped!(
          user: user,
          task: task,
          event_type: "runner_lease_expired",
          message: "Guardrail: demoted expired RUNNING task back to Up Next: #{task.name.truncate(60)}",
          event_id: "runner_lease_expired:task:#{task.id}:lease:#{lease.id}"
        )
      end

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
      task.actor_emoji = "??"
      task.activity_note = "Auto-demoted: in_progress without Runner Lease for > #{NO_FAKE_IN_PROGRESS_GRACE.inspect}"

      demote_to_up_next!(task)
      broadcast_update(task, old_status: old_status)

      if HeartbeatAlertGuard.allow?(key: "task:#{task.id}:lease_missing", state: task.agent_claimed_at&.to_i || task.updated_at.to_i)
        Notification.create_deduped!(
          user: user,
          task: task,
          event_type: "runner_lease_missing",
          message: "Guardrail: demoted task without lease back to Up Next: #{task.name.truncate(60)}",
          event_id: "runner_lease_missing:task:#{task.id}:#{task.updated_at.to_i}"
        )
      end

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

    guard_key = "user:#{user.id}:zombie_detected"
    return zombie_count unless HeartbeatAlertGuard.allow?(key: guard_key, state: zombie_count, cache: @cache)

    Notification.create_deduped!(
      user: user,
      event_type: "zombie_detected",
      message: "Zombie KPI: #{zombie_count} in-progress task(s) look stale (> #{ZOMBIE_STALE_AFTER.inspect} without updates)",
      event_id: "zombie_detected:user:#{user.id}:count:#{zombie_count}",
      ttl: ZOMBIE_NOTIFY_COOLDOWN
    )

    @cache.write(cache_key, Time.current.to_i, expires_in: ZOMBIE_NOTIFY_COOLDOWN)

    @logger.warn("[AgentAutoRunner] zombie KPI user_id=#{user.id} count=#{zombie_count}")

    zombie_count
  end

  def demote_to_up_next!(task, release_lease: nil)
    release_lease&.release!
    task.update!(status: :up_next, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)
  end

  def broadcast_update(task, old_status:)
    KanbanChannel.broadcast_refresh(
      task.board_id,
      task_id: task.id,
      action: "update",
      old_status: old_status,
      new_status: task.status
    )
  end
end
