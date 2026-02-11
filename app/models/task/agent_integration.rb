module Task::AgentIntegration
  extend ActiveSupport::Concern

  included do
    after_update :notify_openclaw_if_urgent, if: -> { saved_change_to_status? || saved_change_to_assigned_to_agent? }
    after_update :warn_if_review_without_session, if: :saved_change_to_status?
    after_update :heartbeat_lease_from_activity_evidence
    after_update :reset_auto_pull_guardrails_if_manual_change
    after_create :try_auto_claim

    validate :agent_output_required_for_done_transition, if: :moving_to_done?
    validate :in_progress_requires_active_lease, if: :moving_to_in_progress?
  end

  # Agent assignment methods
  def assign_to_agent!
    update!(assigned_to_agent: true, assigned_at: Time.current)
  end

  def unassign_from_agent!
    update!(assigned_to_agent: false, assigned_at: nil)
  end

  # Error state methods
  def errored?
    error_at.present?
  end

  def clear_error!
    update!(error_message: nil, error_at: nil)
  end

  def set_error!(message)
    update!(error_message: message, error_at: Time.current)
  end

  # Handoff to a different model - clears error and resets for retry
  def handoff!(new_model:, include_transcript: false)
    updates = {
      error_message: nil,
      error_at: nil,
      retry_count: 0,  # Reset retry count on handoff
      status: :in_progress,
      model: new_model,
      agent_claimed_at: nil  # Allow re-claim by agent
    }

    # Optionally preserve session for context continuity
    unless include_transcript
      updates[:agent_session_id] = nil
      updates[:agent_session_key] = nil
      updates[:context_usage_percent] = nil
    end

    update!(updates)
  end

  # Increment retry count (for auto-retry feature)
  def increment_retry!
    increment!(:retry_count)
  end

  # Check if max retries exceeded
  def max_retries_exceeded?(max_retries = nil)
    max = max_retries || user.auto_retry_max || 3
    retry_count >= max
  end

  # Follow-up task methods
  def followup_task?
    parent_task_id.present? && !parent_task&.recurring?
  end

  def generate_followup_suggestion
    # Try AI-powered suggestion first
    ai_suggestion = AiSuggestionService.new(user).generate_followup(self)
    return ai_suggestion if ai_suggestion.present?

    # Fallback to keyword-based suggestion
    case status
    when "in_review"
      generate_review_followup
    when "done"
      generate_done_followup
    else
      generate_generic_followup
    end
  end

  def generate_review_followup
    suggestions = []

    # Check for common patterns in description
    desc = description.to_s.downcase

    if desc.include?("bug") || desc.include?("issue") || desc.include?("error")
      suggestions << "Fix the identified bugs/issues"
    end

    if desc.include?("security") || desc.include?("exposed") || desc.include?("credential")
      suggestions << "Rotate exposed credentials and implement fixes"
    end

    if desc.include?("api") || desc.include?("endpoint")
      suggestions << "Update API documentation"
    end

    if desc.include?("test") || desc.include?("✅")
      suggestions << "Write additional tests for edge cases"
    end

    if desc.include?("ui") || desc.include?("modal") || desc.include?("menu")
      suggestions << "Polish UI/UX based on testing feedback"
    end

    # Default review suggestions
    suggestions << "Test the implementation manually" if suggestions.empty?
    suggestions << "Document changes for future reference"

    "## Suggested Next Steps\n\n#{suggestions.map { |s| "- #{s}" }.join("\n")}"
  end

  def generate_done_followup
    suggestions = [
      "Iterate based on user feedback",
      "Add tests if not already covered",
      "Update documentation",
      "Consider performance optimizations"
    ]

    "## Suggested Next Steps\n\n#{suggestions.map { |s| "- #{s}" }.join("\n")}"
  end

  def generate_generic_followup
    "## Follow-up\n\nContinue work on: #{name}\n\nDescribe what you want to do next."
  end

  # Review methods
  def review_in_progress?
    review_status == "running"
  end

  def review_passed?
    review_status == "passed"
  end

  def review_failed?
    review_status == "failed"
  end

  def has_review?
    review_type.present?
  end

  def debate_review?
    review_type == "debate"
  end

  def command_review?
    review_type == "command"
  end

  def debate_storage_path
    File.expand_path("~/clawdeck/storage/debates/task_#{id}")
  end

  def debate_synthesis_path
    File.join(debate_storage_path, "synthesis.md")
  end

  def debate_synthesis_content
    return nil unless File.exist?(debate_synthesis_path)
    File.read(debate_synthesis_path)
  end

  def start_review!(type:, config: {})
    update!(
      review_type: type,
      review_config: config,
      review_status: "pending",
      review_result: {}
    )
  end

  def complete_review!(status:, result: {})
    updates = {
      review_status: status,
      review_result: result.merge(completed_at: Time.current.iso8601)
    }

    if status == "passed"
      updates[:status] = "in_review"
    end

    update!(updates)

    # Create follow-up task if failed
    if status == "failed" && result[:error_summary].present?
      create_followup_task!(
        followup_name: "Fix: #{name.truncate(40)}",
        followup_description: "## Review Failed\n\n#{result[:error_summary]}\n\n---\n\n### Original Task\n#{description}"
      )
    end
  end

  def create_followup_task!(followup_name:, followup_description: nil)
    followup = board.tasks.new(
      user: user,
      name: followup_name,
      description: followup_description,
      parent_task_id: id,
      status: :inbox,
      priority: priority,
      model: model  # Inherit model from parent
    )
    followup.activity_source = activity_source
    followup.actor_name = actor_name
    followup.actor_emoji = actor_emoji
    followup.save!

    # Link this task to the followup
    update!(followup_task_id: followup.id)
    followup
  end

  # Runner lease helpers (truthfulness invariant)
  def active_runner_lease
    runner_leases.active.order(expires_at: :desc).first
  end

  def runner_lease_active?
    active_runner_lease.present?
  end

  def runner_last_heartbeat_at
    active_runner_lease&.last_heartbeat_at
  end

  def runner_started_at
    active_runner_lease&.started_at
  end

  def runner_age_seconds
    return nil unless runner_started_at
    (Time.current - runner_started_at).to_i
  end

  def runner_heartbeat_age_seconds
    return nil unless runner_last_heartbeat_at
    (Time.current - runner_last_heartbeat_at).to_i
  end

  def heartbeat_runner_lease!
    lease = active_runner_lease
    lease&.heartbeat!
  end

  # Agent activity visibility: show panel even when session_id is missing
  # if we can infer an agent run happened.
  def show_agent_activity?
    agent_session_id.present? ||
      has_agent_output_marker? ||
      (in_progress? && assigned_to_agent?)
  end

  def has_agent_output_marker?
    description.to_s.include?("## Agent Output")
  end

  def requires_agent_output_for_done?
    assigned_to_agent? || agent_session_id.present? || assigned_at.present?
  end

  def missing_agent_output?
    requires_agent_output_for_done? && !has_agent_output_marker?
  end

  def agent_output_posted_at
    return nil unless has_agent_output_marker?

    # Best signal: when task moved into review (agent_complete default flow)
    in_review_activity = activities
      .where(action: "moved", field_name: "status", new_value: "in_review")
      .order(created_at: :desc)
      .first

    in_review_activity&.created_at || completed_at || updated_at
  end

  private

  def moving_to_done?
    will_save_change_to_status? && self.status == "done"
  end

  def moving_to_in_progress?
    will_save_change_to_status? && self.status == "in_progress"
  end

  def agent_output_required_for_done_transition
    return unless requires_agent_output_for_done?
    return if has_agent_output_marker?

    errors.add(:status, "Cannot mark as done without Agent Output. Use 'Recuperar del Transcript' in the task panel, or add ## Agent Output manually.")
  end

  # Truthfulness invariant:
  # A task may only be in_progress if there is verifiable run evidence.
  # We enforce this only for agent-assigned tasks to avoid breaking
  # human-only workflows.
  def in_progress_requires_active_lease
    return unless assigned_to_agent?

    # Accept a linked session as legacy/equivalent evidence.
    return if runner_lease_active? || agent_session_id.present?

    errors.add(:status, "cannot be In Progress without an active Runner Lease (or a linked agent session)")
  end

  # Warn if task moves to in_review without a linked session (debugging aid)
  def warn_if_review_without_session
    return unless self.status == "in_review" && agent_session_id.blank?
    Rails.logger.warn("[Task##{id}] Task '#{name}' moved to in_review WITHOUT agent_session_id — agent output may be lost!")
  end

  # Any verifiable "agent evidence" should renew the lease, keeping the UI
  # truthful about what is actually running.
  def heartbeat_lease_from_activity_evidence
    return unless in_progress?
    return unless assigned_to_agent?

    relevant = saved_change_to_agent_session_id? ||
      saved_change_to_agent_claimed_at? ||
      saved_change_to_description? ||
      saved_change_to_output_files? ||
      saved_change_to_status?

    return unless relevant

    heartbeat_runner_lease!
  rescue StandardError => e
    Rails.logger.warn("[Task##{id}] lease heartbeat failed: #{e.class}: #{e.message}")
  end

  # Notify OpenClaw gateway when a task becomes runnable for the orchestrator.
  #
  # OpenClaw is the sole orchestrator: ClawTrol should never auto-claim/promote.
  # We only WAKE OpenClaw so it can poll/claim/spawn based on the task settings.
  def notify_openclaw_if_urgent
    return unless user.openclaw_gateway_url.present?

    # Only wake when this task is runnable from the queue.
    return unless self.status == "up_next" && assigned_to_agent? && !blocked?

    OpenclawNotifyJob.perform_later(id)
  end

  # Reset circuit breaker fields on manual (web) edits, so a human can unblock
  # a task and let auto-pull try again.
  def reset_auto_pull_guardrails_if_manual_change
    return unless activity_source == "web"
    return unless saved_change_to_status? || saved_change_to_assigned_to_agent?

    return unless respond_to?(:auto_pull_failures) && respond_to?(:auto_pull_blocked)

    return unless auto_pull_failures.to_i > 0 || auto_pull_blocked?

    update_columns(
      auto_pull_failures: 0,
      auto_pull_blocked: false,
      auto_pull_last_error_at: nil,
      auto_pull_last_error: nil
    )
  rescue StandardError => e
    Rails.logger.warn("[Task##{id}] reset_auto_pull_guardrails failed: #{e.class}: #{e.message}")
  end

  # Try to auto-queue this task based on board settings.
  #
  # IMPORTANT: ClawTrol does not start work. It may move tasks into Up Next +
  # assign them, then wake OpenClaw to decide when/how to run.
  def try_auto_claim
    return unless self.status == "inbox"
    return unless board.can_auto_claim?
    return unless board.task_matches_auto_claim?(self)

    # Lock the board row to prevent race conditions when two tasks are
    # created simultaneously — both could pass can_auto_claim? before
    # either calls record_auto_claim!.
    old_status = self.status

    board.with_lock do
      # Re-check inside the lock since another transaction may have
      # claimed between our optimistic check above and acquiring the lock.
      return unless board.reload.can_auto_claim?

      now = Time.current

      update!(
        assigned_to_agent: true,
        assigned_at: now,
        agent_claimed_at: nil,
        status: :up_next
      )

      # Record the auto-queue time on the board (rate limiting)
      board.record_auto_claim!
    end

    # Record activity
    TaskActivity.create!(
      task: self,
      user: user,
      action: "auto_queued",
      source: "system",
      actor_name: "Auto-Queue",
      actor_emoji: "🤖",
      note: "Task auto-queued based on board settings"
    )

    # Notify UIs that this card moved columns
    KanbanChannel.broadcast_refresh(
      board_id,
      task_id: id,
      action: "update",
      old_status: old_status,
      new_status: self.status
    )

    # Wake the orchestrator
    if user.openclaw_gateway_url.present?
      AutoClaimNotifyJob.perform_later(id)
    end
  end
end
