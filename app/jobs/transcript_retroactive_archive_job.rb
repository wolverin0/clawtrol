# frozen_string_literal: true

# TranscriptRetroactiveArchiveJob — Retroactively archives transcripts for tasks
# that completed before TranscriptArchiveService was added to agent_complete.
#
# Also cleans up agent_activity_events that were ingested from the wrong session
# (false-positive auto-linking from the orchestrator session).
#
# Safe to run multiple times — idempotent by design.
# Schedule: run once on deploy, then weekly as cleanup.
class TranscriptRetroactiveArchiveJob < ApplicationJob
  queue_as :default

  # Tasks with activity events >> this are likely polluted from orchestrator session
  POLLUTION_THRESHOLD = 500

  def perform
    archive_missing_transcripts
    cleanup_polluted_events
  end

  private

  # For tasks with a linked session but few (<= 10) activity events, try to archive.
  def archive_missing_transcripts
    candidates = Task
      .where.not(agent_session_id: nil)
      .where(status: [:in_review, :done])
      .joins("LEFT JOIN agent_activity_events ON agent_activity_events.task_id = tasks.id")
      .group("tasks.id")
      .having("COUNT(agent_activity_events.id) <= 10")
      .order(updated_at: :desc)
      .limit(100)

    archived = 0
    candidates.each do |task|
      result = TranscriptArchiveService.call(task: task, session_id: task.agent_session_id)
      archived += result[:ingested].to_i if result[:ingested].to_i > 0
    end

    Rails.logger.info("[TranscriptRetroarchive] Archived #{archived} events across #{candidates.size} tasks")
  end

  # Tasks with way too many events likely have the orchestrator session linked.
  # Purge events for known-polluted tasks if we can confirm the session is wrong.
  def cleanup_polluted_events
    polluted = Task
      .joins(:agent_activity_events)
      .group("tasks.id")
      .having("COUNT(agent_activity_events.id) > #{POLLUTION_THRESHOLD}")
      .where(status: [:in_review, :done])

    cleaned = 0
    polluted.each do |task|
      next unless orchestrator_session?(task)

      Rails.logger.warn("[TranscriptRetroarchive] Clearing #{task.agent_activity_events.count} events for task ##{task.id} (orchestrator session)")
      task.agent_activity_events.delete_all
      task.update_column(:agent_session_id, nil) # Reset so SessionAutoLinkerJob can re-link
      cleaned += 1
    end

    Rails.logger.info("[TranscriptRetroarchive] Cleaned #{cleaned} polluted tasks")
  end

  # Heuristic: a session is the orchestrator if it was started LONG before the task was created.
  # Workers are spawned within minutes of the task being claimed.
  def orchestrator_session?(task)
    return false if task.agent_session_id.blank?

    transcript_path = TranscriptParser.transcript_path(task.agent_session_id)
    return false unless transcript_path

    begin
      first_line = File.foreach(transcript_path).first.to_s.strip
      return false if first_line.blank?
      ts = JSON.parse(first_line)["timestamp"]
      return false if ts.blank?

      session_started_at = Time.parse(ts)
      task_start = task.agent_claimed_at || task.created_at

      # If session started more than 10 minutes before the task → orchestrator
      (task_start - session_started_at) > 600
    rescue
      false
    end
  end
end
