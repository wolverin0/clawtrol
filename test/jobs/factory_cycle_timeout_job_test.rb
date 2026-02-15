# frozen_string_literal: true

require "test_helper"

class FactoryCycleTimeoutJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @loop = FactoryLoop.create!(
      name: "Test Loop",
      slug: "test-loop-timeout-#{SecureRandom.hex(4)}",
      model: "minimax",
      interval_ms: 60_000,
      status: "playing",
      user: @user
    )
    @cycle_log = FactoryCycleLog.create!(
      factory_loop: @loop,
      cycle_number: 1,
      status: "running",
      started_at: 20.minutes.ago
    )
  end

  test "times out a running cycle" do
    FactoryCycleTimeoutJob.perform_now(@cycle_log.id)
    @cycle_log.reload
    assert_equal "timed_out", @cycle_log.status
    assert_not_nil @cycle_log.finished_at
    assert_match(/timed out/i, @cycle_log.summary)
  end

  test "times out a pending cycle" do
    @cycle_log.update!(status: "pending")
    FactoryCycleTimeoutJob.perform_now(@cycle_log.id)
    @cycle_log.reload
    assert_equal "timed_out", @cycle_log.status
  end

  test "does not touch completed cycle" do
    @cycle_log.update!(status: "completed", finished_at: 5.minutes.ago, summary: "done fine")
    FactoryCycleTimeoutJob.perform_now(@cycle_log.id)
    @cycle_log.reload
    assert_equal "completed", @cycle_log.status
    assert_equal "done fine", @cycle_log.summary
  end

  test "does not touch failed cycle" do
    @cycle_log.update!(status: "failed", finished_at: 3.minutes.ago)
    FactoryCycleTimeoutJob.perform_now(@cycle_log.id)
    @cycle_log.reload
    assert_equal "failed", @cycle_log.status
  end

  test "handles missing cycle log gracefully" do
    assert_nothing_raised do
      FactoryCycleTimeoutJob.perform_now(999_999)
    end
  end

  test "increments loop error counts on timeout" do
    original_errors = @loop.total_errors
    FactoryCycleTimeoutJob.perform_now(@cycle_log.id)
    @loop.reload
    assert @loop.total_errors > original_errors
  end
end
