# frozen_string_literal: true

# Presenter for cost analytics data transformation.
# Extracts view model logic from AnalyticsController#show.
class CostAnalyticsPresenter
  VALID_PERIODS = %w[24h 7d 30d all].freeze

  def initialize(data:, period: "7d")
    @data = data
    @period = VALID_PERIODS.include?(period) ? period : "7d"
  end

  attr_reader :generated_at, :start_time, :total_cost, :total_input, :total_output,
              :total_cache_read, :total_cache_write, :total_tokens, :cost_by_model,
              :max_model_cost, :daily_cost, :max_daily_cost, :top_sessions,
              :api_calls, :cache_hit_rate, :projected_monthly

  def render
    @generated_at = parse_time(@data[:generatedAt])
    @start_time = parse_start_time
    @total_cost = @data.dig(:stats, :totalCost) || 0.0
    @total_input = @data.dig(:tokens, :input) || 0
    @total_output = @data.dig(:tokens, :output) || 0
    @total_cache_read = @data.dig(:tokens, :cacheRead) || 0
    @total_cache_write = @data.dig(:tokens, :cacheWrite) || 0
    @total_tokens = @data.dig(:stats, :totalTokens) || 0

    @cost_by_model = (@data[:costByModel] || []).each_with_object({}) do |entry, h|
      h[entry[:model]] = entry[:cost]
    end
    @max_model_cost = @cost_by_model.values.max || 0.0

    @daily_cost = (@data[:costOverTime] || []).each_with_object({}) do |entry, h|
      h[Date.parse(entry[:date])] = entry[:cost]
    end
    @max_daily_cost = @daily_cost.values.max || 0.0

    @top_sessions = (@data[:topSessions] || []).map do |entry|
      { sessionId: entry[:session], cost: entry[:cost] }
    end

    @api_calls = @data.dig(:stats, :apiCalls) || 0
    @cache_hit_rate = ((@data.dig(:stats, :cacheHitRate) || 0) * 100).round(1)
    @projected_monthly = calculate_projected_monthly

    self
  end

  private

  def parse_time(value)
    begin
      Time.parse(value)
    rescue ArgumentError, StandardError
      Time.current
    end
  end

  def parse_start_time
    return nil unless @data[:rangeStart].present?

    parse_time(@data[:rangeStart])
  end

  def calculate_projected_monthly
    return nil unless @daily_cost.any? && @period.in?(%w[7d 30d])

    days = @daily_cost.size.to_f
    daily_avg = total_cost / days
    (daily_avg * 30).round(4)
  end
end
