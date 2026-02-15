# frozen_string_literal: true

# Live Events Feed: mission-control style view of OpenClaw gateway activity.
# Shows recent tool calls, model responses, cron executions, and webhook hits.
class LiveEventsController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /live
  def show
    @health_data = gateway_client.health
    @sessions_data = gateway_client.sessions_list
    @cron_data = gateway_client.cron_list
    @channels_data = gateway_client.channels_status

    @gateway_status = extract_gateway_status(@health_data)
    @active_sessions = extract_active_sessions(@sessions_data)
    @recent_cron_runs = extract_recent_cron(@cron_data)
    @channel_status = extract_channel_status(@channels_data)
    @recent_webhooks = current_user.respond_to?(:webhook_logs) ?
      current_user.webhook_logs.recent.limit(15) : []
  end

  # GET /live/poll.json — lightweight poll endpoint for live updates
  def poll
    health = gateway_client.health
    sessions = gateway_client.sessions_list

    render json: {
      timestamp: Time.current.iso8601,
      gateway: {
        status: health.is_a?(Hash) && health["error"].blank? ? "online" : "offline",
        uptime: health.is_a?(Hash) ? health["uptime"] : nil,
        version: health.is_a?(Hash) ? health["version"] : nil
      },
      sessions: {
        count: Array(sessions.is_a?(Hash) ? sessions["sessions"] : []).size,
        active: Array(sessions.is_a?(Hash) ? sessions["sessions"] : []).count { |s|
          s.is_a?(Hash) && s["status"] == "active"
        }
      }
    }
  end

  private

  def extract_gateway_status(health)
    return { status: "offline", uptime: nil, version: nil } unless health.is_a?(Hash) && health["error"].blank?

    {
      status: "online",
      uptime: health["uptime"],
      version: health["version"],
      pid: health["pid"],
      started_at: health["startedAt"] || health["started"],
      loaded_plugins: Array(health["loadedPlugins"] || health["plugins"]).size,
      memory_mb: health["memoryMB"] || health.dig("memory", "rss")
    }
  end

  def extract_active_sessions(data)
    return [] unless data.is_a?(Hash) && data["error"].blank?

    sessions = data["sessions"] || []
    Array(sessions).first(20).map do |s|
      {
        key: s["key"],
        kind: s["kind"] || "main",
        model: s["model"],
        status: s["status"] || "active",
        last_activity: s["lastActivity"],
        tokens_used: s["tokensUsed"] || s["contextUsed"] || 0,
        tool_in_progress: s["currentTool"] || s["activeToolCall"]
      }
    end
  end

  def extract_recent_cron(data)
    return [] unless data.is_a?(Hash) && data["error"].blank?

    jobs = data["jobs"] || []
    Array(jobs).first(10).map do |j|
      {
        id: j["id"] || j["jobId"],
        name: j["name"],
        enabled: j.fetch("enabled", true),
        last_run: j["lastRun"] || j["lastRunAt"],
        next_run: j["nextRun"] || j["nextRunAt"],
        schedule: j.dig("schedule", "expr") || j.dig("schedule", "kind")
      }
    end
  end

  def extract_channel_status(data)
    return [] unless data.is_a?(Hash) && data["error"].blank?

    channels = data["channels"] || []
    Array(channels).map do |c|
      {
        name: c["name"] || c["type"],
        connected: c["connected"] || c["online"] || false,
        last_message: c["lastMessage"] || c["lastActivity"]
      }
    end
  end
end
