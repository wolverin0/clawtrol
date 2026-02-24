# frozen_string_literal: true

# Retrieves task-scoped agent transcript/log for a task.
#
# Strict behavior:
# - Never fallback to task description/output files.
# - Never fallback to unrelated sessions.
# - If no valid mapped session/transcript exists, return persisted task-scoped
#   sidecar events (if any) and has_session=false.
class AgentLogService
  SESSION_ID_FORMAT = /\A[a-zA-Z0-9_\-]+\z/
  TASK_MARKER_LINES = 20

  Result = Struct.new(:messages, :total_lines, :has_session, :fallback, :error, :task_status, :since, :persisted_count, keyword_init: true)

  def initialize(task, since: 0, session_resolver: nil)
    @task = task
    @since = since.to_i
    @session_resolver = session_resolver
  end

  def call
    lazy_resolve_session_id!

    persisted_scope = @task.agent_activity_events.ordered
    persisted_count = persisted_scope.count

    return persisted_only_result(persisted_scope, persisted_count) unless @task.agent_session_id.present?

    session_id = @task.agent_session_id.to_s
    return persisted_only_result(persisted_scope, persisted_count) unless session_id.match?(SESSION_ID_FORMAT)

    transcript_path = TranscriptParser.transcript_path(session_id)
    return persisted_only_result(persisted_scope, persisted_count) unless transcript_path
    return persisted_only_result(persisted_scope, persisted_count) unless transcript_matches_task_scope?(transcript_path)

    parsed = TranscriptParser.parse_messages(transcript_path, since: @since)
    ingest_transcript_messages(parsed[:messages], session_id)

    Result.new(
      messages: parsed[:messages],
      total_lines: parsed[:total_lines],
      since: @since,
      has_session: true,
      task_status: @task.status,
      persisted_count: persisted_count
    )
  end

  private

  def lazy_resolve_session_id!
    return if @task.agent_session_id.present?

    # Try session_key resolution first
    if @task.agent_session_key.present? && @session_resolver
      resolved_id = @session_resolver.call(@task.agent_session_key, @task)
      if resolved_id.present?
        @task.update_column(:agent_session_id, resolved_id)
        Rails.logger.info("[AgentLogService] Lazy-resolved session_id=#{resolved_id} for task #{@task.id}")
        return
      end
    end

    # Fallback: scan recent transcripts for task reference (for in_progress tasks)
    scan_recent_transcripts_for_task!
  end

  def scan_recent_transcripts_for_task!
    sessions_dir = TranscriptParser::SESSIONS_DIR
    return unless Dir.exist?(sessions_dir)

    cutoff = Time.current - 12.hours
    recent_files = Dir.glob(File.join(sessions_dir, "*.jsonl"))
                      .select { |f| File.mtime(f) > cutoff }
                      .sort_by { |f| -File.mtime(f).to_i }
                      .first(20) # limit to 20 most recent

    recent_files.each do |fpath|
      # Quick check: read first 20 lines for task reference
      sample = File.foreach(fpath).first(20).join rescue next
      task_patterns = ["Task ##{@task.id}", "task_id.*#{@task.id}", "tasks/#{@task.id}"]
      if task_patterns.any? { |p| sample.include?(p) }
        session_id = File.basename(fpath, ".jsonl")
        # Handle topic-suffixed files (e.g. UUID-topic-1.jsonl)
        session_id = session_id.sub(/-topic-\d+$/, "")
        if session_id.match?(/\A[a-zA-Z0-9_\-]+\z/)
          @task.update_column(:agent_session_id, session_id)
          Rails.logger.info("[AgentLogService] Auto-linked session_id=#{session_id} for task #{@task.id} from transcript scan")
          return
        end
      end
    end
  end

  def transcript_matches_task_scope?(transcript_path)
    sample_lines = []
    File.foreach(transcript_path).with_index do |line, idx|
      break if idx >= TASK_MARKER_LINES
      sample_lines << line
    end

    sample = sample_lines.join
    task_patterns = ["Task ##{@task.id}:", "## Task ##{@task.id}:", "Task ##{@task.id}"]
    has_task_marker = task_patterns.any? { |pattern| sample.include?(pattern) }
    return false unless has_task_marker

    return true if @task.agent_session_key.blank?

    sample.include?(@task.agent_session_key.to_s) || sample.include?("\"session_key\":\"#{@task.agent_session_key}\"")
  rescue StandardError
    false
  end

  def persisted_only_result(persisted_scope, persisted_count)
    events = persisted_scope.where("seq > ?", @since).to_a
    messages = events.map(&:as_agent_log_message)
    total_lines = persisted_scope.maximum(:seq).to_i

    Result.new(
      messages: messages,
      total_lines: total_lines,
      has_session: false,
      task_status: @task.status,
      persisted_count: persisted_count,
      since: @since
    )
  end

  def ingest_transcript_messages(messages, session_id)
    return if messages.blank?

    run_id = @task.last_run_id.presence || session_id.presence || "task-#{@task.id}"

    events = messages.filter_map do |msg|
      seq = msg[:line].to_i
      next if seq <= 0

      {
        run_id: run_id,
        source: "agent_log",
        level: "info",
        event_type: event_type_for_message(msg),
        message: extract_message_text(msg),
        seq: seq,
        created_at: msg[:timestamp],
        payload: {
          role: msg[:role],
          raw: msg
        }
      }
    end

    AgentActivityIngestionService.call(task: @task, events: events) if events.any?
  rescue StandardError => e
    Rails.logger.warn("[AgentLogService] sidecar ingest failed for task=#{@task.id}: #{e.message}")
  end

  def event_type_for_message(msg)
    role = msg[:role].to_s
    return "tool_result" if role == "toolResult"

    if msg[:content].is_a?(Array) && msg[:content].any? { |c| c[:type].to_s == "tool_call" }
      return "tool_call"
    end

    "message"
  end

  def extract_message_text(msg)
    return "" unless msg[:content].is_a?(Array)

    msg[:content].map { |c| c[:text].to_s if c[:text].present? }.compact.join("\n").slice(0, 5000)
  end
end
