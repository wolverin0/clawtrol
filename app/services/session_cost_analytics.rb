# frozen_string_literal: true

require "json"
require "time"

# Parses OpenClaw session JSONL logs and produces cost/token analytics.
#
# Data source:
#   ~/.openclaw/agents/main/sessions/*.jsonl
#
# Expected JSONL entries:
#   {"type":"message","timestamp":"ISO","message":{"role":"assistant","usage":{...},"model":"..."}}
class SessionCostAnalytics
  SESSION_DIR = File.expand_path("~/.openclaw/agents/main/sessions").freeze

  PERIODS = {
    "7d" => 7.days,
    "30d" => 30.days,
    "all" => nil
  }.freeze

  def self.call(period: "7d")
    new(period: period).call
  end

  def initialize(period: "7d")
    @period = PERIODS.key?(period) ? period : "7d"
  end

  def call
    start_time = PERIODS[@period]
    start_time = start_time&.ago

    totals = {
      cost: 0.0,
      api_calls: 0,
      tokens: {
        input: 0,
        output: 0,
        cache_read: 0,
        cache_write: 0
      }
    }

    by_model = Hash.new { |h, k| h[k] = { cost: 0.0, tokens: 0, calls: 0 } }
    by_day = Hash.new { |h, k| h[k] = { cost: 0.0, tokens: 0 } }
    by_session = Hash.new { |h, k| h[k] = { cost: 0.0, tokens: 0, model: nil, last_seen: nil } }

    files = Dir.glob(File.join(SESSION_DIR, "*.jsonl"))

    files.each do |path|
      session_key = File.basename(path, ".jsonl")

      File.foreach(path) do |line|
        line = line.strip
        next if line.empty?

        row = JSON.parse(line) rescue nil
        next unless row.is_a?(Hash)
        next unless row["type"] == "message"

        ts = parse_time(row["timestamp"])
        next if ts.nil?
        next if start_time && ts < start_time

        msg = row["message"]
        next unless msg.is_a?(Hash)
        next unless msg["role"] == "assistant"

        usage = msg["usage"]
        next unless usage.is_a?(Hash)

        input = usage["input"].to_i
        output = usage["output"].to_i
        cache_read = usage["cacheRead"].to_i
        cache_write = usage["cacheWrite"].to_i
        model = msg["model"].presence || "unknown"

        cost_total = (usage.dig("cost", "total") ||
          [ usage.dig("cost", "input"), usage.dig("cost", "output"), usage.dig("cost", "cacheRead"), usage.dig("cost", "cacheWrite") ].compact.sum).to_f

        tokens_total = input + output + cache_read + cache_write

        totals[:api_calls] += 1
        totals[:cost] += cost_total
        totals[:tokens][:input] += input
        totals[:tokens][:output] += output
        totals[:tokens][:cache_read] += cache_read
        totals[:tokens][:cache_write] += cache_write

        by_model[model][:calls] += 1
        by_model[model][:cost] += cost_total
        by_model[model][:tokens] += tokens_total

        day_key = ts.in_time_zone.to_date.iso8601
        by_day[day_key][:cost] += cost_total
        by_day[day_key][:tokens] += tokens_total

        by_session[session_key][:cost] += cost_total
        by_session[session_key][:tokens] += tokens_total
        by_session[session_key][:model] ||= model
        by_session[session_key][:last_seen] = ts if by_session[session_key][:last_seen].nil? || ts > by_session[session_key][:last_seen]
      end
    end

    total_tokens = totals[:tokens].values.sum
    cache_read = totals[:tokens][:cache_read]
    cache_hit_rate = total_tokens.positive? ? (cache_read.to_f / total_tokens) : 0.0

    # Normalize series (fill missing days for 7d/30d)
    series = normalize_daily_series(by_day, start_time)

    {
      generatedAt: Time.current.iso8601,
      period: @period,
      rangeStart: start_time&.iso8601,
      stats: {
        totalCost: totals[:cost].round(6),
        totalTokens: total_tokens,
        apiCalls: totals[:api_calls],
        cacheHitRate: cache_hit_rate
      },
      tokens: {
        input: totals[:tokens][:input],
        output: totals[:tokens][:output],
        cacheRead: totals[:tokens][:cache_read],
        cacheWrite: totals[:tokens][:cache_write]
      },
      costByModel: by_model.map { |model, v|
        {
          model: model,
          cost: v[:cost].round(6),
          tokens: v[:tokens],
          calls: v[:calls]
        }
      }.sort_by { |r| -r[:cost] },
      costOverTime: series.map { |date, v|
        {
          date: date,
          cost: v[:cost].round(6),
          tokens: v[:tokens]
        }
      },
      topSessions: by_session.map { |session, v|
        {
          session: session,
          cost: v[:cost].round(6),
          tokens: v[:tokens],
          model: v[:model] || "unknown",
          lastSeen: v[:last_seen]&.iso8601
        }
      }.sort_by { |r| -r[:cost] }.first(5)
    }
  end

  private

  def parse_time(str)
    return nil if str.blank?
    Time.iso8601(str) rescue nil
  end

  def normalize_daily_series(by_day, start_time)
    return by_day.sort.to_h if start_time.nil?

    start_date = start_time.to_date
    end_date = Date.current

    (start_date..end_date).each_with_object({}) do |date, h|
      key = date.iso8601
      h[key] = by_day[key] || { cost: 0.0, tokens: 0 }
    end
  end
end
