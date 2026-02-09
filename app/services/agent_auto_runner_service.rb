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
  # Lease-based truthfulness invariant:
  # - in_progress tasks must have an active RunnerLease (or a linked session).
  # - leases expire if we don't see heartbeats.
  NO_FAKE_IN_PROGRESS_GRACE = 10.minutes
  LEASE_STALE_AFTER = 10.minutes
  ZOMBIE_STALE_AFTER = 30.minutes
  SPAWN_COOLDOWN = 1.minute
  ZOMBIE_NOTIFY_COOLDOWN = 60.minutes
  FAILURE_COOLDOWN = 5.minutes
  FAILURE_LIMIT = 3

  NIGHT_TZ = "America/Argentina/Buenos_Aires"

  def initialize(logger: Rails.logger, cache: Rails.cache, openclaw_gateway_client: OpenclawGatewayClient)
    @logger = logger
    @cache = cache
    @openclaw_gateway_client = openclaw_gateway_client
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

      stats[:tasks_demoted] += demote_expired_or_missing_leases!(user)
      stats[:zombie_tasks] += notify_zombies_if_any!(user)

      next if agent_currently_working?(user)

      if spawn_if_work_available!(user)
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
    # Consider the agent busy if any in_progress task has an active lease.
    RunnerLease.active.joins(:task).where(tasks: { user_id: user.id, status: Task.statuses[:in_progress] }).exists?
  end

  def runnable_up_next_task_for(user)
    scope = user.tasks
      .where(status: :up_next, blocked: false, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)
      .where(auto_pull_blocked: false)
      .where("auto_pull_last_error_at IS NULL OR auto_pull_last_error_at < ?", Time.current - FAILURE_COOLDOWN)
      .where.not(recurring: true, parent_task_id: nil) # never auto-run recurring templates

    # Apply nightly gating
    tasks = scope.order(priority: :desc, position: :asc, assigned_to_agent: :desc, assigned_at: :asc).to_a
    tasks.find { |t| eligible_for_time_window?(t) }
  end

  def spawn_if_work_available!(user)
    task = runnable_up_next_task_for(user)
    return false unless task

    cache_key = "agent_auto_runner:last_spawn:user:#{user.id}"
    return false if @cache.read(cache_key).present?

    claim_for_auto_pull!(task)

    Notification.create_deduped!(
      user: user,
      task: task,
      event_type: "auto_pull_claimed",
      message: "Auto-pull claimed: #{task.name.truncate(60)}"
    )

    prompt = build_openclaw_prompt(task)
    task.update_columns(auto_pull_last_attempt_at: Time.current)
    spawn = @openclaw_gateway_client.new(user).spawn_session!(model: task.openclaw_spawn_model, prompt: prompt)

    task.update!(
      agent_session_key: spawn[:child_session_key],
      agent_session_id: spawn[:session_id],
      auto_pull_failures: 0,
      auto_pull_blocked: false,
      auto_pull_last_error_at: nil,
      auto_pull_last_error: nil
    )

    Notification.create_deduped!(
      user: user,
      task: task,
      event_type: "auto_pull_spawned",
      message: "Auto-pull spawned session for: #{task.name.truncate(60)}"
    )

    @cache.write(cache_key, Time.current.to_i, expires_in: SPAWN_COOLDOWN)

    @logger.info("[AgentAutoRunner] auto-pull spawned user_id=#{user.id} task_id=#{task.id} session_key=#{task.agent_session_key}")
    true
  rescue StandardError => e
    @logger.error("[AgentAutoRunner] auto-pull spawn failed user_id=#{user.id} task_id=#{task&.id} err=#{e.class}: #{e.message}")

    begin
      mark_auto_pull_failure!(task, e) if task
      revert_auto_pull_claim!(task) if task

      Notification.create_deduped!(
        user: user,
        task: task,
        event_type: "auto_pull_error",
        message: "Auto-pull spawn failed: #{e.class}: #{e.message}".truncate(250)
      )
    rescue StandardError
      # Don't let notification errors break the runner.
    end

    false
  end

  def claim_for_auto_pull!(task)
    task.activity_source = "system"
    task.actor_name = "Auto-Runner"
    task.actor_emoji = "🤖"
    task.activity_note = "Auto-pull: leased + claimed + spawning OpenClaw session"

    now = Time.current

    # Create lease first so the Task model validation can enforce
    # in_progress ⇔ active lease.
    RunnerLease.create!(
      task: task,
      agent_name: task.user&.agent_name,
      lease_token: SecureRandom.hex(24),
      source: "auto_runner",
      started_at: now,
      last_heartbeat_at: now,
      expires_at: now + RunnerLease::LEASE_DURATION
    )

    updates = {
      assigned_to_agent: true,
      assigned_at: task.assigned_at || now,
      agent_claimed_at: now,
      status: :in_progress
    }

    task.update!(updates)
  end

  def revert_auto_pull_claim!(task)
    return unless task

    task.activity_source = "system"
    task.actor_name = "Auto-Runner"
    task.actor_emoji = "🤖"
    task.activity_note = "Auto-pull: spawn failed, reverting claim + releasing lease"

    # Release any active lease so the invariant stays truthful.
    task.runner_leases.where(released_at: nil).update_all(released_at: Time.current)

    task.update!(
      status: :up_next,
      assigned_to_agent: false,
      assigned_at: nil,
      agent_claimed_at: nil,
      agent_session_id: nil,
      agent_session_key: nil
    )
  end

  def mark_auto_pull_failure!(task, error)
    return unless task.respond_to?(:auto_pull_failures)

    failures = task.auto_pull_failures.to_i + 1
    blocked = failures >= FAILURE_LIMIT

    task.update_columns(
      auto_pull_failures: failures,
      auto_pull_blocked: blocked,
      auto_pull_last_error_at: Time.current,
      auto_pull_last_error: "#{error.class}: #{error.message}".truncate(500)
    )
  rescue StandardError
    # best-effort; never crash the runner
  end

  def eligible_for_time_window?(task)
    return true unless task.nightly?

    now = Time.current.in_time_zone(NIGHT_TZ)
    start_hour = Rails.configuration.x.auto_runner.nightly_start_hour
    end_hour = Rails.configuration.x.auto_runner.nightly_end_hour

    in_window = if start_hour < end_hour
      now.hour >= start_hour && now.hour < end_hour
    else
      # window spans midnight (default 23 -> 8)
      now.hour >= start_hour || now.hour < end_hour
    end

    return false unless in_window

    delay_hours = task.nightly_delay_hours.to_i
    return true if delay_hours <= 0

    # Anchor the "night start" to the current window.
    night_start_date = now.hour >= start_hour ? now.to_date : (now.to_date - 1.day)
    night_start = Time.find_zone!(NIGHT_TZ).local(night_start_date.year, night_start_date.month, night_start_date.day, start_hour, 0, 0)

    now >= (night_start + delay_hours.hours)
  end

  def build_openclaw_prompt(task)
    validation = task.validation_command.present? ? "\n\n## Validation\nRun:\n```bash\n#{task.validation_command}\n```\n" : ""
    hooks_token = Rails.application.config.hooks_token.to_s

    <<~PROMPT
      ## Task ##{task.id}: #{task.name}

      Project repo: /home/ggorbalan/clawdeck

      #{task.description}
      #{validation}

      ## Constraints
      - You are a sub-agent spawned by ClawTrol server-side auto-pull.
      - ALWAYS report completion with an OutcomeContract (YES/NO follow-up) first, then attach your raw output via agent_complete.

      If you set `needs_follow_up=true` with `recommended_action=requeue_same_task`, ClawTrol will move THIS SAME TASK back to `up_next` and wake OpenClaw immediately (no new follow-up card bloat).

      ```bash
      RUN_ID="$(ruby -e 'require \"securerandom\"; puts SecureRandom.uuid')"
      ENDED_AT="$(date -Iseconds)"

      curl -s -X POST http://192.168.100.186:4001/api/v1/hooks/task_outcome \
        -H "X-Hook-Token: #{hooks_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "version":"1",
          "task_id":#{task.id},
          "run_id":"'"$RUN_ID"'",
          "ended_at":"'"$ENDED_AT"'",
          "needs_follow_up":false,
          "recommended_action":"in_review",
          "summary":"<one paragraph>",
          "achieved":["..."],
          "evidence":["..."],
          "remaining":["..."]
        }'

      curl -s -X POST http://192.168.100.186:4001/api/v1/hooks/agent_complete \
        -H "X-Hook-Token: #{hooks_token}" \
        -H "Content-Type: application/json" \
        -d '{"task_id":#{task.id},"findings":"SUMMARY + COMMIT HASH + test command","output_files":["..."]}'
      ```

      Make sure the JSON includes real output_files paths.
    PROMPT
  end

  # Truthfulness invariant (lease-based):
  # - if a task is in_progress + assigned_to_agent, it must have an active lease
  #   (or a linked agent session as legacy evidence).
  # - expired leases are auto-demoted back to up_next and the lease is released.
  def demote_expired_or_missing_leases!(user)
    count = 0

    # 1) Expired leases
    RunnerLease.expired.joins(:task).where(tasks: { user_id: user.id, status: Task.statuses[:in_progress] }).find_each do |lease|
      task = lease.task

      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "🤖"
      task.activity_note = "Auto-demoted: Runner Lease expired (last hb #{lease.last_heartbeat_at&.iso8601})"

      lease.release!
      task.update!(status: :up_next, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)

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

    # 2) Missing lease (legacy / drift) — keep a short grace window.
    cutoff = Time.current - NO_FAKE_IN_PROGRESS_GRACE
    active_lease_task_ids = RunnerLease.active.where(task_id: user.tasks.select(:id)).select(:task_id)

    tasks = user.tasks
      .where(status: :in_progress, assigned_to_agent: true, agent_session_id: nil)
      .where("tasks.updated_at < ?", cutoff)
      .where.not(id: active_lease_task_ids)

    tasks.find_each do |task|
      task.activity_source = "system"
      task.actor_name = "Auto-Runner"
      task.actor_emoji = "🤖"
      task.activity_note = "Auto-demoted: in_progress without Runner Lease for > #{NO_FAKE_IN_PROGRESS_GRACE.inspect}"

      task.update!(status: :up_next, agent_claimed_at: nil)

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
