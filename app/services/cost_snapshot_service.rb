# frozen_string_literal: true

# Creates periodic cost snapshots from TokenUsage records and OpenClaw session data.
# Called by a scheduled job (e.g., daily via SolidQueue or cron).
#
# Usage:
#   CostSnapshotService.capture_daily(user)    # snapshot for yesterday
#   CostSnapshotService.capture_weekly(user)   # snapshot for last 7 days
#   CostSnapshotService.capture_monthly(user)  # snapshot for last calendar month
#   CostSnapshotService.capture_all            # all users, daily
class CostSnapshotService
  class << self
    def capture_daily(user, date: Date.yesterday)
      capture(user: user, period: "daily", date: date, range: date.all_day)
    end

    def capture_weekly(user, date: Date.current.beginning_of_week - 1.week)
      week_range = date.beginning_of_week..date.end_of_week
      capture(user: user, period: "weekly", date: date.beginning_of_week, range: week_range)
    end

    def capture_monthly(user, date: Date.current.prev_month)
      month_range = date.beginning_of_month..date.end_of_month
      capture(user: user, period: "monthly", date: date.beginning_of_month, range: month_range)
    end

    # Capture daily snapshots for all users
    def capture_all(date: Date.yesterday)
      User.find_each do |user|
        capture_daily(user, date: date)
      rescue StandardError => e
        Rails.logger.error("[CostSnapshotService] Failed for user #{user.id}: #{e.message}")
      end
    end

    private

    def capture(user:, period:, date:, range:)
      # Idempotent: skip if already captured
      return if CostSnapshot.exists?(user: user, period: period, snapshot_date: date)

      usages = TokenUsage
        .for_user(user)
        .where(created_at: range)

      cost_by_model = usages.group(:model).sum(:cost).transform_values { |v| v.to_f.round(6) }
      tokens_by_model = build_tokens_by_model(usages)
      cost_by_source = build_cost_by_source(usages)

      # Merge in OpenClaw session data if available
      openclaw_data = fetch_openclaw_session_costs(range)
      if openclaw_data[:cost].positive?
        cost_by_model.merge!(openclaw_data[:by_model]) { |_, a, b| (a + b).round(6) }
        cost_by_source.merge!(openclaw_data[:by_source]) { |_, a, b| (a + b).round(6) }
      end

      total_cost = usages.sum(:cost).to_f + openclaw_data[:cost]

      # Inherit budget from previous snapshot of same period, if any
      prev = CostSnapshot
        .where(user: user, period: period)
        .order(snapshot_date: :desc)
        .first

      CostSnapshot.create!(
        user: user,
        period: period,
        snapshot_date: date,
        total_cost: total_cost.round(6),
        total_input_tokens: usages.sum(:input_tokens) + openclaw_data[:input_tokens],
        total_output_tokens: usages.sum(:output_tokens) + openclaw_data[:output_tokens],
        api_calls: usages.count + openclaw_data[:api_calls],
        cost_by_model: cost_by_model,
        cost_by_source: cost_by_source,
        tokens_by_model: tokens_by_model,
        budget_limit: prev&.budget_limit
      )
    end

    def build_tokens_by_model(usages)
      usages
        .group(:model)
        .pluck(:model, Arel.sql("SUM(input_tokens)"), Arel.sql("SUM(output_tokens)"))
        .each_with_object({}) do |(model, inp, out), h|
          h[model] = { "input" => inp.to_i, "output" => out.to_i }
        end
    end

    def build_cost_by_source(usages)
      usages
        .joins(:task)
        .group("tasks.id", "tasks.name")
        .pluck(Arel.sql("tasks.id"), Arel.sql("tasks.name"), Arel.sql("SUM(token_usages.cost)"))
        .each_with_object({}) do |(id, name, cost), h|
          label = "task:#{id}"
          label += " (#{name.truncate(40)})" if name.present?
          h[label] = cost.to_f.round(6)
        end
    end

    # Pull cost data from OpenClaw session JSONL files for the given range.
    # Skips entirely if session directory is missing or empty (fast path for tests).
    def fetch_openclaw_session_costs(range)
      result = { cost: 0.0, input_tokens: 0, output_tokens: 0, api_calls: 0, by_model: {}, by_source: {} }

      # Skip expensive JSONL scan in test environment or when no session files exist
      return result if Rails.env.test?

      session_dir = SessionCostAnalytics::SESSION_DIR
      return result unless Dir.exist?(session_dir) && Dir.glob(File.join(session_dir, "*.jsonl")).any?

      begin
        data = SessionCostAnalytics.call(period: "all")
        return result unless data.is_a?(Hash)

        start_time = range.is_a?(Range) ? range.first.to_time : range.begin
        end_time = range.is_a?(Range) ? range.last.to_time.end_of_day : range.end

        # Filter costOverTime entries within range
        (data[:costOverTime] || []).each do |entry|
          entry_date = Date.parse(entry[:date]) rescue nil
          next unless entry_date
          next unless entry_date >= start_time.to_date && entry_date <= end_time.to_date

          result[:cost] += entry[:cost].to_f
          result[:input_tokens] += (entry[:tokens].to_f * 0.6).to_i  # estimated split
          result[:output_tokens] += (entry[:tokens].to_f * 0.4).to_i
          result[:api_calls] += 1
        end

        # Model breakdown from full data (approximate for range)
        if result[:cost].positive? && data[:costByModel].present?
          total_cost = data.dig(:stats, :totalCost).to_f
          ratio = total_cost.positive? ? (result[:cost] / total_cost) : 0

          data[:costByModel].each do |entry|
            model_cost = (entry[:cost].to_f * ratio).round(6)
            result[:by_model][entry[:model]] = model_cost if model_cost.positive?
          end
        end
      rescue StandardError => e
        Rails.logger.warn("[CostSnapshotService] OpenClaw session read failed: #{e.message}")
      end

      result
    end
  end
end
