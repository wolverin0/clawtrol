# frozen_string_literal: true

# TranscriptArchiveService — Permanently ingests a full JSONL transcript into AgentActivityEvent records.
#
# Called from:
#   - Api::V1::HooksController#agent_complete (synchronous, before JSONL can be deleted)
#   - TranscriptCaptureJob (fallback for tasks that complete without proper hooks)
#
# Why this matters:
#   OpenClaw deletes/archives session JSONL files. AgentLogService reads from them lazily
#   during polling. If the JSONL is deleted before the Transcript tab is ever opened,
#   all agent work becomes invisible forever.
#
#   This service reads the FULL transcript at hook time and persists it into the DB,
#   so the Transcript tab always has data regardless of JSONL file lifecycle.
class TranscriptArchiveService
  MAX_EVENTS_PER_TASK = 2_000  # Safety cap — prevents runaway from huge sessions
  BATCH_SIZE          = 100

  def self.call(task:, session_id: nil)
    new(task: task, session_id: session_id).call
  end

  def initialize(task:, session_id: nil)
    @task       = task
    @session_id = session_id.presence || task.agent_session_id.presence
  end

  def call
    return { ingested: 0, skipped: "no session_id" } if @session_id.blank?

    # Clean UUID from prefixed formats (e.g. "agent:main:subagent:UUID")
    clean_id = @session_id.to_s.include?(":") ? @session_id.split(":").last : @session_id.to_s
    return { ingested: 0, skipped: "invalid session_id" } unless clean_id.match?(/\A[a-zA-Z0-9_\-]+\z/)

    transcript_path = TranscriptParser.transcript_path(clean_id)
    return { ingested: 0, skipped: "transcript not found (session=#{clean_id})" } unless transcript_path

    # If we already have a full archive (events > 10), skip to avoid duplication
    existing_count = @task.agent_activity_events.count
    if existing_count > 10
      Rails.logger.debug("[TranscriptArchive] task ##{@task.id} already has #{existing_count} events — skipping re-ingest")
      return { ingested: 0, skipped: "already ingested (#{existing_count} events)" }
    end

    run_id = @task.last_run_id.presence || clean_id

    parsed = TranscriptParser.parse_messages(transcript_path, since: 0)
    messages = parsed[:messages].first(MAX_EVENTS_PER_TASK)

    return { ingested: 0, skipped: "no messages parsed" } if messages.blank?

    events = messages.filter_map do |msg|
      seq = msg[:line].to_i
      next if seq <= 0

      {
        run_id: run_id,
        source: "transcript_archive",
        level: "info",
        event_type: event_type_for(msg),
        message: message_text_for(msg),
        seq: seq,
        created_at: msg[:timestamp] || Time.current,
        payload: { role: msg[:role], raw: msg }
      }
    end

    ingested = 0
    events.each_slice(BATCH_SIZE) do |batch|
      result = AgentActivityIngestionService.call(task: @task, events: batch)
      ingested += batch.size
    end

    Rails.logger.info("[TranscriptArchive] task ##{@task.id} ← #{ingested} events from #{File.basename(transcript_path)}")
    { ingested: ingested, transcript_path: transcript_path }
  rescue => e
    Rails.logger.error("[TranscriptArchive] task ##{@task.id}: #{e.class}: #{e.message}")
    { ingested: 0, error: e.message }
  end

  private

  def event_type_for(msg)
    role = msg[:role].to_s
    return "tool_result" if role == "toolResult"
    if msg[:content].is_a?(Array) && msg[:content].any? { |c| c[:type].to_s == "tool_call" }
      return "tool_call"
    end
    role == "assistant" ? "assistant_message" : "user_message"
  end

  def message_text_for(msg)
    content = msg[:content]
    return content.to_s if content.is_a?(String)
    return "" unless content.is_a?(Array)
    content.filter_map do |part|
      case part[:type].to_s
      when "text"       then part[:text].to_s.strip
      when "tool_call"  then "▶ #{part[:name]}(#{part[:input].to_json.truncate(200) rescue '...'})"
      when "tool_result" then "← #{part[:content].to_s.truncate(300)}"
      end
    end.join("\n").strip
  end
end
