# frozen_string_literal: true

require "test_helper"

class FactoryRunnerJobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @loop = FactoryLoop.create!(
      name: "Test Factory Loop",
      slug: "test-factory-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "minimax",
      status: "playing",
      user: @user,
      openclaw_cron_id: "cron-#{SecureRandom.hex(4)}"
    )
  end

  # Test: loop not found
  test "does nothing if loop not found" do
    assert_nothing_raised do
      FactoryRunnerJob.perform_now(-1)
    end
    assert_equal 0, FactoryCycleLog.count
  end

  # Test: loop not playing
  test "does nothing if loop is not playing" do
    @loop.update!(status: "paused")
    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end
    assert_equal 0, FactoryCycleLog.count
  end

  # Test: loop stopped
  test "does nothing if loop is stopped" do
    @loop.update!(status: "stopped")
    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end
    assert_equal 0, FactoryCycleLog.where(factory_loop: @loop).count
  end

  # Test: creates cycle log with correct cycle number
  test "creates cycle log with incremented cycle number" do
    FactoryRunnerJob.perform_now(@loop.id)

    assert_equal 1, FactoryCycleLog.count
    cycle = FactoryCycleLog.first
    assert_equal 1, cycle.cycle_number
  end

  # Test: increments cycle number on subsequent runs
  test "increments cycle number on subsequent runs" do
    3.times do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    assert_equal 3, FactoryCycleLog.count
  end

  # Test: increments failures on wake failure
  test "increments failures on wake failure" do
    @user.update!(openclaw_gateway_url: "http://invalid-host-that-does-not-exist.test:9999")
    @loop.update!(consecutive_failures: 0, total_errors: 0)

    FactoryRunnerJob.perform_now(@loop.id)

    @loop.reload
    assert_equal 1, @loop.consecutive_failures
    assert_equal 1, @loop.total_errors
  end

  # Test: handles race condition gracefully
  test "handles race condition on duplicate cycle numbers" do
    FactoryCycleLog.create!(
      factory_loop: @loop,
      cycle_number: 1,
      started_at: Time.current,
      status: "running"
    )

    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end
  end
end
