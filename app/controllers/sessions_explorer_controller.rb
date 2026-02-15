# frozen_string_literal: true

class SessionsExplorerController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication

  # GET /sessions
  def index
    result = Rails.cache.fetch("sessions/list/#{current_user.id}", expires_in: 10.seconds) do
      gateway_client.sessions_list
    end

    all_sessions = Array(result["sessions"] || result[:sessions] || [])
    @error = result["error"] if result.is_a?(Hash) && result["error"]

    # Categorize sessions
    @sessions_by_kind = all_sessions.group_by { |s| classify_session(s) }
    @total_count = all_sessions.size
    @active_count = all_sessions.count { |s| active?(s) }

    # Link sessions to ClawTrol tasks
    session_keys = all_sessions.filter_map { |s| s["key"] || s["sessionKey"] }
    @task_links = if session_keys.any?
      current_user.tasks
        .where(agent_session_id: session_keys)
        .pluck(:agent_session_id, :id, :name, :board_id)
        .each_with_object({}) { |(key, id, name, board_id), h| h[key] = { id: id, name: name, board_id: board_id } }
    else
      {}
    end
  end

  private

  def classify_session(session)
    kind = (session["kind"] || session["type"] || "").to_s.downcase
    return "main" if kind.include?("main")
    return "cron" if kind.include?("cron")
    return "hook" if kind.include?("hook") || kind.include?("webhook")
    return "subagent" if kind.include?("sub") || kind.include?("spawn") || kind.include?("child")
    "other"
  end

  def active?(session)
    status = (session["status"] || "").to_s.downcase
    status.match?(/active|running|open/)
  end
end
