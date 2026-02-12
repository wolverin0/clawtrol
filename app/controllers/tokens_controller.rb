require "open3"
require "timeout"

class TokensController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json do
        data = fetch_tokens
        if data[:status] == "offline"
          render json: data, status: :service_unavailable
        else
          render json: data
        end
      rescue StandardError => e
        Rails.logger.error("TOKENS ERROR: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { status: "offline", error: e.message }, status: :service_unavailable
      end
    end
  end

  private

  def fetch_tokens
    active_minutes = Integer(ENV.fetch("OPENCLAW_SESSIONS_ACTIVE_MINUTES_FOR_TOKENS", "1440"))

    result = Rails.cache.fetch(tokens_cache_key(active_minutes), expires_in: cache_ttl) do
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

    total_tokens = sessions.sum { |s| s[:totalTokens].to_i }

    {
      status: "online",
      source: "cli",
      activeMinutes: raw["activeMinutes"] || active_minutes,
      count: sessions.length,
      totalTokens: total_tokens,
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
    stdout, stderr, status = Timeout.timeout(openclaw_timeout_seconds) do
      Open3.capture3("openclaw", "sessions", "--active", active_minutes.to_s, "--json")
    end

    { stdout: stdout, stderr: stderr, exitstatus: status&.exitstatus }
  end

  def normalize_session(session)
    updated_at = ms_to_time(session["updatedAt"])

    total_tokens = session["totalTokens"]

    {
      id: session["sessionId"] || session["key"],
      sessionId: session["sessionId"],
      key: session["key"].to_s,
      model: session["model"],
      totalTokens: total_tokens,
      updatedAt: updated_at&.iso8601(3),
      abortedLastRun: session["abortedLastRun"],
      kind: session["key"].to_s.include?(":cron:") ? "cron" : "agent"
    }
  end

  def ms_to_time(ms)
    return nil if ms.blank?
    Time.at(ms.to_f / 1000.0)
  rescue StandardError
    nil
  end

  def openclaw_timeout_seconds
    Integer(ENV.fetch("OPENCLAW_COMMAND_TIMEOUT_SECONDS", "20"))
  rescue ArgumentError
    20
  end

  def cache_ttl
    Integer(ENV.fetch("TOKENS_CACHE_TTL_SECONDS", "5")).seconds
  rescue ArgumentError
    5.seconds
  end

  def tokens_cache_key(active_minutes)
    "tokens/index/v1/active_minutes=#{active_minutes}"
  end
end
