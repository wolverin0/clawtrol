# frozen_string_literal: true

require "listen"

# TranscriptWatcher: Watches OpenClaw agent transcript files for changes
# and broadcasts new messages via ActionCable in real-time.
#
# This replaces polling-based updates with push-based streaming.
# Uses the Listen gem with rb-inotify for efficient file watching.
#
# Usage:
#   TranscriptWatcher.instance.start   # Start watching (called by initializer)
#   TranscriptWatcher.instance.stop    # Stop watching (called on shutdown)
#
class TranscriptWatcher
  include Singleton

  SESSIONS_DIR = TranscriptParser::SESSIONS_DIR
  DEBOUNCE_MS = 100  # Debounce rapid file changes

  def initialize
    @listener = nil
    @file_offsets = {}  # Track read position per file: { "session_id" => line_number }
    @mutex = Mutex.new
    @running = false
  end

  def start
    return if @running
    return unless Dir.exist?(SESSIONS_DIR)

    @running = true
    Rails.logger.info "[TranscriptWatcher] Starting file watcher on #{SESSIONS_DIR}"

    @listener = Listen.to(
      SESSIONS_DIR,
      only: /\.jsonl$/,
      latency: DEBOUNCE_MS / 1000.0,
      wait_for_delay: DEBOUNCE_MS / 1000.0
    ) do |modified, added, _removed|
      # Handle both new files and modifications
      (modified + added).uniq.each do |file_path|
        process_file_change(file_path)
      end
    end

    @listener.start
    Rails.logger.info "[TranscriptWatcher] Watcher started successfully"
  rescue StandardError => e
    Rails.logger.error "[TranscriptWatcher] Failed to start: #{e.message}"
    @running = false
  end

  def stop
    return unless @running

    Rails.logger.info "[TranscriptWatcher] Stopping file watcher"
    @listener&.stop
    @listener = nil
    @running = false
    @mutex.synchronize { @file_offsets.clear }
  end

  def running?
    @running
  end

  private

  def process_file_change(file_path)
    return unless File.exist?(file_path)

    session_id = File.basename(file_path, ".jsonl")

    # Skip invalid session IDs
    return unless session_id.match?(/\A[a-zA-Z0-9_\-]+\z/)

    # Find active tasks using this session
    tasks = find_tasks_for_session(session_id)
    return if tasks.empty?

    # Read new lines since last position
    new_messages, total_lines = read_new_lines(file_path, session_id)
    return if new_messages.empty?

    # Broadcast to each task's WebSocket channel
    tasks.each do |task|
      broadcast_to_task(task.id, new_messages, total_lines)
    end
  rescue StandardError => e
    Rails.logger.error "[TranscriptWatcher] Error processing #{file_path}: #{e.message}"
  end

  def find_tasks_for_session(session_id)
    # Find tasks that are in_progress or up_next with this session
    # Use a quick database query (indexed by agent_session_id)
    Task.where(agent_session_id: session_id)
        .where(status: [:in_progress, :up_next])
        .to_a
  rescue StandardError => e
    Rails.logger.warn "[TranscriptWatcher] Failed to find tasks for session #{session_id}: #{e.message}"
    []
  end

  def read_new_lines(file_path, session_id)
    messages = []
    total_lines = 0

    @mutex.synchronize do
      last_line = @file_offsets[session_id] || 0
      current_line = 0

      File.foreach(file_path) do |line|
        current_line += 1
        next if current_line <= last_line

        parsed = parse_transcript_line(line, current_line)
        messages << parsed if parsed
      end

      total_lines = current_line
      @file_offsets[session_id] = current_line
    end

    [messages, total_lines]
  rescue StandardError => e
    Rails.logger.warn "[TranscriptWatcher] Failed to read #{file_path}: #{e.message}"
    [[], 0]
  end

  def parse_transcript_line(line, line_number)
    TranscriptParser.parse_line(line, line_number)
  end

  def broadcast_to_task(task_id, messages, total_lines)
    AgentActivityChannel.broadcast_activity(task_id, {
      messages: messages,
      total_lines: total_lines
    })

    persist_events(task_id, messages)

    Rails.logger.debug "[TranscriptWatcher] Broadcast #{messages.size} messages to task #{task_id}"
  rescue StandardError => e
    Rails.logger.error "[TranscriptWatcher] Broadcast failed for task #{task_id}: #{e.message}"
  end

  def persist_events(task_id, messages)
    task = Task.find_by(id: task_id)
    return unless task

    run_id = task.last_run_id.presence || task.agent_session_id.presence || "task-#{task.id}"

    events = messages.map do |msg|
      {
        run_id: run_id,
        source: "transcript_watcher",
        level: "info",
        event_type: event_type_for_message(msg),
        message: extract_message_text(msg),
        seq: msg[:line].to_i,
        created_at: msg[:timestamp],
        payload: {
          role: msg[:role],
          raw: msg
        }
      }
    end

    AgentActivityIngestionService.call(task: task, events: events)
  rescue StandardError => e
    Rails.logger.warn "[TranscriptWatcher] Failed to persist events task=#{task_id}: #{e.message}"
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

  # Reset offset for a session (useful for testing or when file is truncated)
  def reset_offset(session_id)
    @mutex.synchronize { @file_offsets.delete(session_id) }
  end

  # Get current offset for a session (for debugging)
  def current_offset(session_id)
    @mutex.synchronize { @file_offsets[session_id] || 0 }
  end
end
