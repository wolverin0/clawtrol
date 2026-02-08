# frozen_string_literal: true

# AgentAutoRunnerService
#
# Purpose:
# - Keep the agent proactive by periodically waking OpenClaw when there are
#   runnable `up_next` tasks assigned to the agent.
# - Enforce a "no-fake-in-progress" invariant: a task may not remain
#   `in_progress` unless it has either an agent session linked OR the agent has
#   claimed it (agent_claimed_at acts as a run marker).
# - Detect likely "zombie" tasks (claimed but stale) and surface a KPI via
#   Notifications.
#
# This service is intended to be run by a lightweight scheduler (cron/systemd
# timer) via `bin/rails clawdeck:agent_auto_runner`.
class AgentAutoRunnerService
  NO_FAKE_IN_PROGRESS_GRACE = 10.minutes
  ZOMBIE_STALE_AFTER = 30.minutes
  WAKE_COOLDOWN = 3.minutes
  ZOMBIE_NOTIFY_COOLDOWN = 60.minutes

  def initialize(logger: Rails.logger, cache: Rails.cache, openclaw_webhook_service: OpenclawWebhookService)
    @logger = logger
    @cache = cache
    @openclaw_webhook_service = openclaw_webhook_service
  end

  def run!
    stats = {
      users_considered: 0,
      users_woken: 0,
      tasks_demoted: 0,
      zombie_tasks: 0
    }

    User.where(agent_auto_mode: true).find_each do |user|
      next unless openclaw_configured?(user)

      stats[:users_considered] += 1

      stats[:tasks_demoted] += demote_fake_in_progress!(user)
      stats[:zombie_tasks] += notify_zombies_if_any!(user)

      next if agent_currently_working?(user)

      if wake_if_work_available!(user)
        stats[:users_woken] += 1
      end
    end

    @logger.info("[AgentAutoRunner] finished stats=#{stats.inspect}")
    stats
  end

  private

  def openclaw_configured?(user)
    user.openclaw_gateway_url.present? && user.openclaw_gateway_token.present?
  end

  def agent_currently_working?(user)
    user.tasks.where(status: :in_progress).where.not(agent_claimed_at: nil).exists?
  end

  def runnable_up_next_task_for(user)
    user.tasks
      .where(status: :up_next, assigned_to_agent: true, blocked: false, agent_claimed_at: nil)
      .order(priority: :desc, position: :asc, assigned_at: :asc)
      .first
  end

  def wake_if_work_available!(user)
    task = runnable_up_next_task_for(user)
    return false unless task

    cache_key = "agent_auto_runner:last_wake:user:#{user.id}"
    return false if @cache.read(cache_key).present?

    @openclaw_webhook_service.new(user).notify_task_assigned(task)

    Notification.create!(
      user: user,
      task: task,
      event_type: "auto_runner",
      message: "Auto-runner woke OpenClaw for: #{task.name.truncate(60)}"
    )

    @cache.write(cache_key, Time.current.to_i, expires_in: WAKE_COOLDOWN)

    @logger.info("[AgentAutoRunner] woke user_id=#{user.id} task_id=#{task.id}")
    true
  rescue StandardError => e
    @logger.error("[AgentAutoRunner] wake failed user_id=#{user.id} task_id=#{task&.id} err=#{e.class}: #{e.message}")
    false
  end

  # No-fake-in-progress invariant:
  # - if a task is in_progress + assigned_to_agent, but has no session AND was never claimed,
  #   it must not stay in_progress indefinitely.
  def demote_fake_in_progress!(user)
    cutoff = Time.current - NO_FAKE_IN_PROGRESS_GRACE

    tasks = user.tasks
      .where(status: :in_progress, assigned_to_agent: true, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)
      .where("updated_at < ?", cutoff)

    count = 0

    tasks.find_each do |task|
      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "🤖"
      task.activity_note = "Auto-demoted: in_progress without agent session/claim for > #{NO_FAKE_IN_PROGRESS_GRACE.inspect}"

      task.update!(status: :up_next)

      Notification.create!(
        user: user,
        task: task,
        event_type: "zombie_task",
        message: "Guardrail: demoted stuck task back to Up Next: #{task.name.truncate(60)}"
      )

      count += 1

      @logger.warn("[AgentAutoRunner] demoted fake-in-progress task_id=#{task.id}")
    rescue StandardError => e
      @logger.error("[AgentAutoRunner] failed to demote task_id=#{task.id} err=#{e.class}: #{e.message}")
    end

    count
  end

  # Zombie KPI:
  # - Count tasks that are claimed (agent_claimed_at present) but have not been updated in a while.
  # - Notify at most once per hour per user to avoid spam.
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

    Notification.create!(
      user: user,
      event_type: "zombie_detected",
      message: "Zombie KPI: #{zombie_count} in-progress task(s) look stale (> #{ZOMBIE_STALE_AFTER.inspect} without updates)"
    )

    @cache.write(cache_key, Time.current.to_i, expires_in: ZOMBIE_NOTIFY_COOLDOWN)

    @logger.warn("[AgentAutoRunner] zombie KPI user_id=#{user.id} count=#{zombie_count}")

    zombie_count
  end
end
