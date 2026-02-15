# frozen_string_literal: true

class CommandController < ApplicationController
  include OpenclawCliRunnable

  def index
    respond_to do |format|
      format.html
      format.json do
        data = fetch_command_center_data
        if data[:status] == "offline"
          render json: data, status: :service_unavailable
        else
          render json: data
        end
      rescue StandardError => e
        Rails.logger.error("COMMAND CENTER ERROR: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { status: "offline", error: e.message }, status: :service_unavailable
      end
    end
  end

  private

  def fetch_command_center_data
    active_minutes = Integer(ENV.fetch("OPENCLAW_SESSIONS_ACTIVE_MINUTES", "120"))

    result = Rails.cache.fetch(command_center_cache_key(active_minutes), expires_in: command_center_cache_ttl) do
      run_openclaw_sessions(active_minutes)
    end

    stdout = result.fetch(:stdout)
    stderr = result.fetch(:stderr)
    exitstatus = result[:exitstatus]

    unless exitstatus == 0
      msg = "openclaw sessions failed"
      msg += " (exit=#{exitstatus})" if exitstatus
      msg += ": #{stderr.strip}" if stderr.present?
      return { status: "offline", error: msg }
    end

    raw = JSON.parse(stdout)
    sessions = Array(raw["sessions"]).map { |s| normalize_session(s) }

    # Best-effort enrichment: try to show a last message snippet even when
    # `openclaw sessions --json` does not include messages.
    sessions.each do |s|
      s[:lastMessageSnippet] = fetch_last_message_snippet(s)
    end

    {
      status: "online",
      source: "cli",
      activeMinutes: raw["activeMinutes"] || active_minutes,
      count: raw["count"] || sessions.length,
      path: raw["path"],
      generatedAt: Time.current.iso8601(3),
      sessions: sessions
    }
  rescue Errno::ENOENT
    { status: "offline", error: "openclaw CLI not found" }
  rescue Timeout::Error
    { status: "offline", error: "openclaw sessions timed out" }
  rescue JSON::ParserError
    { status: "offline", error: "invalid JSON from openclaw sessions" }
  end

  def run_openclaw_sessions(active_minutes)
    run_openclaw_cli("sessions", "--active", active_minutes.to_s, "--json")
  end

  def command_center_cache_ttl
    Integer(ENV.fetch("COMMAND_CENTER_CACHE_TTL_SECONDS", "5")).seconds
  rescue ArgumentError
    5.seconds
  end

  def command_center_cache_key(active_minutes)
    "command_center/sessions/v1/active_minutes=#{active_minutes}"
  end

  def normalize_session(session)
    key = session["key"].to_s
    kind = key.include?(":cron:") ? "cron" : "agent"

    updated_at_ms = session["updatedAt"]
    updated_at = begin
      updated_at_ms ? Time.at(updated_at_ms.to_f / 1000.0) : nil
    rescue StandardError
      nil
    end

    {
      id: session["sessionId"] || key,
      sessionId: session["sessionId"],
      key: key,
      label: key,
      kind: kind,
      model: session["model"],
      totalTokens: session["totalTokens"],
      tokens: session["totalTokens"],
      updatedAt: updated_at&.iso8601(3),
      lastActive: updated_at&.iso8601(3),
      status: "running",
      abortedLastRun: session["abortedLastRun"]
    }
  end

  def openclaw_sessions_dir
    File.expand_path(ENV["OPENCLAW_SESSIONS_DIR"].presence || "~/.openclaw/agents/main/sessions")
  end

  def fetch_last_message_snippet(session)
    session_id = session[:sessionId].presence || session[:id].presence
    key = session[:key].to_s

    filenames = []

    # Security: never allow path traversal. Only allow safe filenames.
    if session_id.present? && safe_session_filename?(session_id)
      filenames << "#{session_id}.jsonl"
    end

    if key.present?
      safe_key = key.gsub(/[^a-zA-Z0-9_.-]+/, "_")
      filenames << "#{safe_key}.jsonl"
    end

    base = openclaw_sessions_dir

    filenames.each do |filename|
      path = safe_join_sessions_path(base, filename)
      next unless path
      next unless File.file?(path)
      return read_last_message_from_jsonl(path)
    end

    nil
  rescue StandardError => e
    Rails.logger.debug("command_center: snippet fetch failed: #{e.class}: #{e.message}")
    nil
  end

  def safe_session_filename?(name)
    name.to_s.match?(/\A[a-zA-Z0-9_.-]+\z/)
  end

  def safe_join_sessions_path(base, filename)
    base = File.expand_path(base)
    path = File.expand_path(File.join(base, filename))
    return nil unless path.start_with?(base + File::SEPARATOR)
    path
  rescue ArgumentError
    nil
  end

  def read_last_message_from_jsonl(path)
    max_bytes = Integer(ENV.fetch("OPENCLAW_SESSION_TAIL_BYTES", "8192"))
    max_bytes = 1024 if max_bytes < 1024
    max_bytes = 64 * 1024 if max_bytes > 64 * 1024

    File.open(path, "rb") do |f|
      size = f.size
      f.seek([size - max_bytes, 0].max, IO::SEEK_SET)
      tail = f.read.to_s

      tail.lines.reverse_each do |line|
        line = line.strip
        next if line.blank?

        obj = JSON.parse(line) rescue nil
        next unless obj.is_a?(Hash)

        msg = extract_message_payload(obj)
        next unless msg

        role = msg["role"] || msg[:role]
        next unless %w[user assistant system].include?(role.to_s)

        content = msg["content"] || msg[:content]
        text = normalize_content_to_text(content)
        next if text.blank?

        # Ignore tool-ish emissions if present.
        next if msg["tool"] || msg["tool_name"] || msg["tool_call_id"]

        text = text.gsub(/\s+/, " ").strip
        return text.length > 140 ? (text[0, 140] + "...") : text
      end
    end

    nil
  rescue Errno::ENOENT
    nil
  end

  def extract_message_payload(obj)
    return obj if obj.key?("role") && obj.key?("content")

    inner = obj["message"] || obj[:message]
    return inner if inner.is_a?(Hash) && (inner.key?("role") || inner.key?(:role))

    nil
  end

  def normalize_content_to_text(content)
    case content
    when String
      content
    when Array
      content.map { |p| p.is_a?(Hash) ? (p["text"] || p[:text] || p["content"] || p[:content]) : p }.join(" ")
    when Hash
      content["text"] || content[:text] || content["content"] || content[:content]
    else
      content.to_s
    end
  end
end
