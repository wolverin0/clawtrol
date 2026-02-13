require "json"
require "time"

require "timeout"

class AnalyticsController < ApplicationController
  before_action :require_authentication

  # Cost Analytics (OpenClaw sessions JSONL)
  def show
    @period = params[:period].presence || "7d"

    @start_time = case @period
    when "24h" then 24.hours.ago
    when "7d" then 7.days.ago
    when "30d" then 30.days.ago
    when "all" then 10.years.ago
    else 7.days.ago
    end

    data = Rails.cache.fetch(analytics_cache_key(@period), expires_in: cache_ttl) do
      parse_openclaw_usage(@start_time)
    end

    @generated_at = data[:generated_at]

    @total_cost = data[:total_cost]
    @total_input = data[:total_input]
    @total_output = data[:total_output]
    @total_cache_read = data[:total_cache_read]
    @total_cache_write = data[:total_cache_write]
    @total_tokens = data[:total_tokens]

    @cost_by_model = data[:cost_by_model]
    @max_model_cost = @cost_by_model.values.max || 0.0

    @daily_cost = data[:daily_cost]
    @max_daily_cost = @daily_cost.values.max || 0.0

    @top_sessions = data[:top_sessions]
  end

  private

  def sessions_dir
    File.expand_path(ENV["OPENCLAW_SESSIONS_DIR"].presence || "~/.openclaw/agents/main/sessions")
  end

  def parse_openclaw_usage(start_time)
    total_cost = 0.0
    totals = {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0
    }

    cost_by_model = Hash.new(0.0)
    daily_cost = Hash.new(0.0)
    session_costs = Hash.new(0.0)

    Dir.glob(File.join(sessions_dir, "*.jsonl")).each do |path|
      next if path.include?(".deleted")

      session_id = File.basename(path).sub(/\.jsonl\z/, "")

      File.foreach(path) do |line|
        obj = JSON.parse(line) rescue nil
        next unless obj.is_a?(Hash)

        msg = obj["message"].is_a?(Hash) ? obj["message"] : obj
        usage = msg["usage"] || obj["usage"]
        next unless usage.is_a?(Hash)

        ts = (obj["timestamp"] || msg["timestamp"]).to_s
        t = begin
          Time.iso8601(ts)
        rescue StandardError
          nil
        end
        next unless t
        next if t < start_time

        model = msg["model"].to_s.presence || "unknown"

        totals[:input] += usage["input"].to_i
        totals[:output] += usage["output"].to_i
        totals[:cacheRead] += usage["cacheRead"].to_i
        totals[:cacheWrite] += usage["cacheWrite"].to_i
        totals[:totalTokens] += usage["totalTokens"].to_i

        cost = usage.dig("cost", "total").to_f
        total_cost += cost
        cost_by_model[model] += cost
        daily_cost[t.to_date] += cost
        session_costs[session_id] += cost
      end
    rescue Errno::ENOENT
      next
    rescue StandardError => e
      Rails.logger.debug("analytics: failed to parse #{path}: #{e.class}: #{e.message}")
      next
    end

    (start_time.to_date..Date.current).each { |d| daily_cost[d] ||= 0.0 }

    top_sessions = session_costs.sort_by { |_, c| -c }.first(12).map do |session_id, cost|
      { sessionId: session_id, cost: cost }
    end

    {
      generated_at: Time.current,
      total_cost: total_cost,
      total_input: totals[:input],
      total_output: totals[:output],
      total_cache_read: totals[:cacheRead],
      total_cache_write: totals[:cacheWrite],
      total_tokens: totals[:totalTokens],
      cost_by_model: cost_by_model.sort_by { |_, c| -c }.to_h,
      daily_cost: daily_cost.sort.to_h,
      top_sessions: top_sessions
    }
  end

  def cache_ttl
    Integer(ENV.fetch("ANALYTICS_CACHE_TTL_SECONDS", "30")).seconds
  rescue ArgumentError
    30.seconds
  end

  def analytics_cache_key(period)
    "analytics/openclaw_cost/v1/period=#{period}"
  end
end
