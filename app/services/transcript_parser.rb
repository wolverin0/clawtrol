# frozen_string_literal: true

# TranscriptParser: Shared module for parsing OpenClaw JSONL session transcripts.
#
# Deduplicates transcript parsing logic used across:
#   - Api::V1::TasksController (agent_log, recover_output, extract_tokens, etc.)
#   - TranscriptWatcher (real-time file watching)
#   - TranscriptCaptureJob (fallback output capture)
#
# Usage:
#   TranscriptParser.sessions_dir
#   TranscriptParser.transcript_path(session_id)              # with archived fallback
#   TranscriptParser.parse_line(line, line_number)             # single JSONL line → parsed message hash
#   TranscriptParser.each_entry(path) { |data, line_num| ... } # iterate raw JSON entries
#   TranscriptParser.parse_messages(path, since: 0)            # all UI messages from a file
#
module TranscriptParser
  SESSIONS_DIR = File.expand_path("~/.openclaw/agents/main/sessions")

  # Valid session ID format (prevents path traversal)
  VALID_SESSION_ID = /\A[a-zA-Z0-9_\-]+\z/

  module_function

  def sessions_dir
    SESSIONS_DIR
  end

  # Returns the transcript file path for a session_id, checking active then archived.
  # Returns nil if not found or session_id is invalid.
  def transcript_path(session_id)
    return nil if session_id.blank?
    return nil unless session_id.to_s.match?(VALID_SESSION_ID)

    active = File.join(SESSIONS_DIR, "#{session_id}.jsonl")
    return active if File.exist?(active)

    # Fallback: archived transcript (.jsonl.deleted.*)
    archived = Dir.glob(File.join(SESSIONS_DIR, "#{session_id}.jsonl.deleted.*")).first
    archived if archived && File.exist?(archived)
  end

  # Parse a single JSONL line into a UI-friendly message hash.
  # Returns nil for non-message lines or parse errors.
  def parse_line(line, line_number = nil)
    return nil if line.blank?

    data = parse_json(line)
    return nil unless data && data["type"] == "message"

    msg = data["message"]
    return nil unless msg

    parsed = {
      id: data["id"],
      line: line_number,
      timestamp: data["timestamp"],
      role: msg["role"]
    }

    content = msg["content"]
    if content.is_a?(Array)
      parsed[:content] = content.map do |item|
        case item["type"]
        when "text"
          { type: "text", text: item["text"]&.slice(0, 2000) }
        when "thinking"
          { type: "thinking", text: item["thinking"]&.slice(0, 500) }
        when "toolCall"
          { type: "tool_call", name: item["name"], id: item["id"] }
        else
          { type: item["type"] || "unknown" }
        end
      end
    elsif content.is_a?(String)
      parsed[:content] = [{ type: "text", text: content.slice(0, 2000) }]
    end

    # Tool results
    if msg["role"] == "toolResult"
      parsed[:tool_call_id] = msg["toolCallId"]
      parsed[:tool_name] = msg["toolName"]
      tool_content = msg["content"]
      if tool_content.is_a?(Array) && tool_content.first
        text = tool_content.first["text"]
        parsed[:content] = [{ type: "tool_result", text: text&.slice(0, 1000) }]
      end
    end

    parsed
  rescue JSON::ParserError
    nil
  end

  # Safely parse a JSON line, returning nil on error.
  def parse_json(line)
    JSON.parse(line.strip)
  rescue JSON::ParserError
    nil
  end

  # Iterate over each raw JSON entry in a transcript file.
  # Yields (data_hash, line_number) for each successfully parsed line.
  def each_entry(path, since: 0)
    return enum_for(:each_entry, path, since: since) unless block_given?

    line_number = 0
    File.foreach(path) do |line|
      line_number += 1
      next if line_number <= since
      next if line.blank?

      data = parse_json(line)
      yield data, line_number if data
    end
    line_number
  end

  # Parse all UI messages from a transcript file.
  # Returns { messages: [...], total_lines: N }
  def parse_messages(path, since: 0)
    messages = []
    total_lines = 0

    File.foreach(path) do |line|
      total_lines += 1
      next if total_lines <= since

      parsed = parse_line(line, total_lines)
      messages << parsed if parsed
    end

    { messages: messages, total_lines: total_lines }
  end

  # Extract the last assistant text that matches summary keywords (for recover_output).
  def extract_summary(path, keywords: nil)
    keywords ||= /\b(completed|done|summary|what i changed|findings|changes made|implemented|fixed)\b/i
    candidate = nil

    each_entry(path) do |data, _line_num|
      next unless data["type"] == "message"
      msg = data["message"]
      next unless msg && msg["role"] == "assistant"

      text = flatten_content_text(msg["content"])
      next if text.blank?

      candidate = text if text.match?(keywords)
    end

    candidate&.strip
  end

  # Flatten message content (Array or String) into plain text.
  def flatten_content_text(content)
    case content
    when String
      content
    when Array
      content
        .select { |item| item.is_a?(Hash) && item["type"] == "text" }
        .map { |item| item["text"].to_s }
        .join("\n")
    else
      ""
    end
  end
end
