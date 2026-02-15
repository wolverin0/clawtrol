# frozen_string_literal: true

class TokensController < ApplicationController
  include OpenclawCliRunnable

  before_action :require_authentication

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
    run_openclaw_cli("sessions", "--active", active_minutes.to_s, "--json")
  end

  def normalize_session(session)
    updated_at = ms_to_time(session["updatedAt"])

    total_tokens = session["totalTokens"].to_i
    context_tokens = session["contextTokens"].to_i
    input_tokens = session["inputTokens"].to_i
    output_tokens = session["outputTokens"].to_i

    context_usage_pct = if context_tokens.positive?
      ((total_tokens.to_f / context_tokens) * 100)
    else
      0.0
    end

    {
      id: session["sessionId"] || session["key"],
      sessionId: session["sessionId"],
      key: session["key"].to_s,
      model: session["model"],
      contextTokens: context_tokens,
      totalTokens: total_tokens,
      inputTokens: input_tokens,
      outputTokens: output_tokens,
      contextUsagePct: context_usage_pct.round(1),
      updatedAt: updated_at&.iso8601(3),
      abortedLastRun: session["abortedLastRun"],
      kind: session["key"].to_s.include?(":cron:") ? "cron" : "agent"
    }
  end

  def cache_ttl
    Integer(ENV.fetch("TOKENS_CACHE_TTL_SECONDS", "5")).seconds
  rescue ArgumentError
    5.seconds
  end

  def tokens_cache_key(active_minutes)
    "tokens/index/v1/user=#{current_user.id}/active_minutes=#{active_minutes}"
  end
end
