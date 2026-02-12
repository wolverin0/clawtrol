require "open3"
require "timeout"

class CommandController < ApplicationController
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

    stdout, stderr, status = run_openclaw_sessions(active_minutes)

    unless status&.success?
      msg = "openclaw sessions failed"
      msg += " (exit=#{status.exitstatus})" if status
      msg += ": #{stderr.strip}" if stderr.present?
      return { status: "offline", error: msg }
    end

    raw = JSON.parse(stdout)
    sessions = Array(raw["sessions"]).map { |s| normalize_session(s) }

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
    Timeout.timeout(4) do
      Open3.capture3(
        "openclaw",
        "sessions",
        "--active",
        active_minutes.to_s,
        "--json"
      )
    end
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
end
