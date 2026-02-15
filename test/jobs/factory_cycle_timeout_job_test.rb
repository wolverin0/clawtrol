# frozen_string_literal: true

require "test_helper"

class FactoryCycleTimeoutJobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @loop = FactoryLoop.create!(
      name: "Timeout Test Loop",
      slug: "timeout-test-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "minimax",
      status: "playing",
      user: @user,
      openclaw_cron_id: "cron-#{SecureRandom.hex(4)}"
    )
  end

  def create_cycle(status: "running", cycle_number: 1)
    FactoryCycleLog.create!(
      factory_loop: @loop,
      cycle_number: cycle_number,
      started_at: Time.current,
      status: status
    )
  end

  test "skips if cycle_log not found" do
    assert_nothing_raised do
      FactoryCycleTimeoutJob.perform_now(-1)
    end
  end

  test "skips if cycle_log is already completed" do
    cycle = create_cycle(status: "completed")
    FactoryCycleTimeoutJob.perform_now(cycle.id)

    cycle.reload
    assert_equal "completed", cycle.status
  end

  test "skips if cycle_log is already timed_out" do
    cycle = create_cycle(status: "timed_out")
    FactoryCycleTimeoutJob.perform_now(cycle.id)

    cycle.reload
    assert_equal "timed_out", cycle.status
  end

  test "skips if cycle_log is already failed" do
    cycle = create_cycle(status: "failed")
    FactoryCycleTimeoutJob.perform_now(cycle.id)

    cycle.reload
    assert_equal "failed", cycle.status
  end

  test "times out a running cycle" do
    cycle = create_cycle(status: "running")
    FactoryCycleTimeoutJob.perform_now(cycle.id)

    cycle.reload
    assert_equal "timed_out", cycle.status
    assert_includes cycle.summary, "timed out"
    assert_not_nil cycle.finished_at
  end

  test "times out a pending cycle" do
    cycle = create_cycle(status: "pending")
    FactoryCycleTimeoutJob.perform_now(cycle.id)

    cycle.reload
    assert_equal "timed_out", cycle.status
    assert_not_nil cycle.finished_at
  end

  test "sets duration_ms on timed out cycle" do
    started = 10.minutes.ago
    cycle = FactoryCycleLog.create!(
      factory_loop: @loop,
      cycle_number: 99,
      started_at: started,
      status: "running"
    )

    FactoryCycleTimeoutJob.perform_now(cycle.id)

    cycle.reload
    assert_not_nil cycle.duration_ms
    assert cycle.duration_ms > 0
  end
end
