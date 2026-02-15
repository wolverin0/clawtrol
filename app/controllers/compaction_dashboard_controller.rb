# frozen_string_literal: true

# Compaction Dashboard: Track session compaction events, context window usage,
# memory flush status, and alert on frequent compactions.
class CompactionDashboardController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /compaction
  def show
    @sessions_data = gateway_client.sessions_list
    @health_data = gateway_client.health

    @sessions = extract_sessions(@sessions_data)
    @stats = compute_stats(@sessions)
    @alerts = compute_alerts(@sessions)
  end

  private

  def extract_sessions(data)
    return [] unless data.is_a?(Hash) && data["error"].blank?

    sessions = data["sessions"] || []
    Array(sessions).map do |s|
      compactions = s["compactionCount"] || s["compactions"] || 0
      context_used = s["contextUsed"] || s["tokensUsed"] || 0
      context_max = s["contextMax"] || s["maxTokens"] || 200_000

      {
        key: s["key"] || s["sessionKey"],
        kind: s["kind"] || "main",
        model: s["model"],
        compactions: compactions,
        context_used: context_used,
        context_max: context_max,
        context_pct: context_max > 0 ? ((context_used.to_f / context_max) * 100).round(1) : 0,
        last_activity: s["lastActivity"] || s["updatedAt"],
        memory_flushed: s["memoryFlushed"] || false,
        compaction_summaries: s["compactionSummaries"] || [],
        status: s["status"] || "active"
      }
    end.sort_by { |s| -(s[:compactions]) }
  end

  def compute_stats(sessions)
    return { total: 0, with_compaction: 0, total_compactions: 0, avg_context_pct: 0 } if sessions.empty?

    with_compaction = sessions.count { |s| s[:compactions] > 0 }
    total_compactions = sessions.sum { |s| s[:compactions] }
    avg_context = sessions.any? ? (sessions.sum { |s| s[:context_pct] } / sessions.size).round(1) : 0

    {
      total: sessions.size,
      with_compaction: with_compaction,
      total_compactions: total_compactions,
      avg_context_pct: avg_context,
      highest_compactions: sessions.first&.dig(:compactions) || 0
    }
  end

  def compute_alerts(sessions)
    alerts = []

    # Sessions with high compaction counts (>3 = potential inefficiency)
    frequent = sessions.select { |s| s[:compactions] > 3 }
    frequent.each do |s|
      alerts << {
        level: "warning",
        session: s[:key],
        message: "Session has #{s[:compactions]} compactions — may indicate inefficient tool use"
      }
    end

    # Sessions near context limit (>80%)
    near_limit = sessions.select { |s| s[:context_pct] > 80 }
    near_limit.each do |s|
      alerts << {
        level: "info",
        session: s[:key],
        message: "Context window #{s[:context_pct]}% full — compaction likely soon"
      }
    end

    alerts
  end
end
