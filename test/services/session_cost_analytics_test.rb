# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "json"
require "fileutils"

class SessionCostAnalyticsTest < ActiveSupport::TestCase
  setup do
    @original_dir = SessionCostAnalytics::SESSION_DIR
    @tmp_dir = Dir.mktmpdir("session_cost_analytics_test")
    # Override the constant for testing
    SessionCostAnalytics.send(:remove_const, :SESSION_DIR)
    SessionCostAnalytics.const_set(:SESSION_DIR, @tmp_dir)
  end

  teardown do
    FileUtils.rm_rf(@tmp_dir) if @tmp_dir && File.exist?(@tmp_dir)
    SessionCostAnalytics.send(:remove_const, :SESSION_DIR)
    SessionCostAnalytics.const_set(:SESSION_DIR, @original_dir)
  end

  # --- Empty directory ---

  test "returns empty analytics when no session files exist" do
    result = SessionCostAnalytics.call(period: "7d")

    assert_equal "7d", result[:period]
    assert_equal 0, result[:stats][:totalCost]
    assert_equal 0, result[:stats][:totalTokens]
    assert_equal 0, result[:stats][:apiCalls]
    assert_empty result[:costByModel]
    assert_empty result[:topSessions]
    assert result[:generatedAt].present?
  end

  # --- Basic token counting ---

  test "counts tokens from a single session file" do
    write_session("test-session", [
      message_entry(model: "claude-opus-4", input: 100, output: 50, cost: 0.005)
    ])

    result = SessionCostAnalytics.call(period: "all")

    assert_equal 1, result[:stats][:apiCalls]
    assert_equal 150, result[:stats][:totalTokens]
    assert_in_delta 0.005, result[:stats][:totalCost], 0.0001
    assert_equal 100, result[:tokens][:input]
    assert_equal 50, result[:tokens][:output]
  end

  # --- Multiple messages ---

  test "aggregates tokens across multiple messages in one session" do
    write_session("multi-msg", [
      message_entry(model: "claude-opus-4", input: 100, output: 50, cost: 0.005),
      message_entry(model: "claude-opus-4", input: 200, output: 100, cost: 0.010)
    ])

    result = SessionCostAnalytics.call(period: "all")

    assert_equal 2, result[:stats][:apiCalls]
    assert_equal 450, result[:stats][:totalTokens]
    assert_in_delta 0.015, result[:stats][:totalCost], 0.0001
  end

  # --- Multiple sessions ---

  test "aggregates across multiple session files" do
    write_session("session-a", [
      message_entry(model: "claude-opus-4", input: 100, output: 50, cost: 0.005)
    ])
    write_session("session-b", [
      message_entry(model: "gemini-2.5-pro", input: 200, output: 100, cost: 0.002)
    ])

    result = SessionCostAnalytics.call(period: "all")

    assert_equal 2, result[:stats][:apiCalls]
    assert_equal 2, result[:costByModel].size

    models = result[:costByModel].map { |m| m[:model] }
    assert_includes models, "claude-opus-4"
    assert_includes models, "gemini-2.5-pro"
  end

  # --- Model breakdown ---

  test "breaks down cost by model sorted by highest cost first" do
    write_session("model-test", [
      message_entry(model: "cheap-model", input: 100, output: 50, cost: 0.001),
      message_entry(model: "expensive-model", input: 100, output: 50, cost: 0.100)
    ])

    result = SessionCostAnalytics.call(period: "all")

    assert_equal "expensive-model", result[:costByModel].first[:model]
    assert_equal "cheap-model", result[:costByModel].last[:model]
  end

  # --- Cache hit rate ---

  test "computes cache hit rate correctly" do
    write_session("cache-test", [
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01, cache_read: 200, cache_write: 50)
    ])

    result = SessionCostAnalytics.call(period: "all")

    total = 100 + 50 + 200 + 50  # 400
    expected_rate = 200.0 / 400   # 0.5
    assert_in_delta expected_rate, result[:stats][:cacheHitRate], 0.01
    assert_equal 200, result[:tokens][:cacheRead]
    assert_equal 50, result[:tokens][:cacheWrite]
  end

  test "cache hit rate is 0 when no tokens" do
    result = SessionCostAnalytics.call(period: "all")
    assert_equal 0.0, result[:stats][:cacheHitRate]
  end

  # --- Period filtering ---

  test "filters messages by 7d period" do
    old_ts = (10.days.ago).iso8601
    recent_ts = (2.days.ago).iso8601

    write_session("period-test", [
      message_entry(model: "claude", input: 1000, output: 500, cost: 0.5, timestamp: old_ts),
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01, timestamp: recent_ts)
    ])

    result = SessionCostAnalytics.call(period: "7d")

    assert_equal 1, result[:stats][:apiCalls]
    assert_equal 150, result[:stats][:totalTokens]
  end

  test "all period includes everything" do
    old_ts = (100.days.ago).iso8601
    recent_ts = Time.current.iso8601

    write_session("all-test", [
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01, timestamp: old_ts),
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01, timestamp: recent_ts)
    ])

    result = SessionCostAnalytics.call(period: "all")

    assert_equal 2, result[:stats][:apiCalls]
  end

  # --- Top sessions ---

  test "returns top 5 sessions by cost" do
    7.times do |i|
      write_session("session-#{i}", [
        message_entry(model: "claude", input: 100, output: 50, cost: (i + 1) * 0.01)
      ])
    end

    result = SessionCostAnalytics.call(period: "all")

    assert_equal 5, result[:topSessions].size
    # Most expensive first
    assert_equal "session-6", result[:topSessions].first[:session]
  end

  # --- Skips non-assistant messages ---

  test "ignores non-assistant messages" do
    entries = [
      { type: "message", timestamp: Time.current.iso8601, message: { role: "user", content: "hello" } }.to_json,
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01)
    ]

    write_session_raw("roles-test", entries)

    result = SessionCostAnalytics.call(period: "all")
    assert_equal 1, result[:stats][:apiCalls]
  end

  # --- Invalid JSON lines ---

  test "skips malformed JSON lines gracefully" do
    entries = [
      "not valid json {{{",
      "",
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01)
    ]

    write_session_raw("malformed-test", entries)

    result = SessionCostAnalytics.call(period: "all")
    assert_equal 1, result[:stats][:apiCalls]
  end

  # --- Default period ---

  test "defaults to 7d when invalid period given" do
    result = SessionCostAnalytics.call(period: "invalid")
    assert_equal "7d", result[:period]
  end

  # --- Daily series normalization ---

  test "fills missing days in daily series for 7d period" do
    recent_ts = (1.day.ago).iso8601
    write_session("series-test", [
      message_entry(model: "claude", input: 100, output: 50, cost: 0.01, timestamp: recent_ts)
    ])

    result = SessionCostAnalytics.call(period: "7d")

    # Should have entries for each day in the 7d range
    assert result[:costOverTime].size >= 7
  end

  private

  def message_entry(model:, input:, output:, cost:, timestamp: nil, cache_read: 0, cache_write: 0)
    ts = timestamp || Time.current.iso8601
    {
      type: "message",
      timestamp: ts,
      message: {
        role: "assistant",
        model: model,
        usage: {
          input: input,
          output: output,
          cacheRead: cache_read,
          cacheWrite: cache_write,
          cost: { total: cost }
        }
      }
    }.to_json
  end

  def write_session(name, entries)
    File.write(File.join(@tmp_dir, "#{name}.jsonl"), entries.join("\n") + "\n")
  end

  def write_session_raw(name, lines)
    File.write(File.join(@tmp_dir, "#{name}.jsonl"), lines.join("\n") + "\n")
  end
end
