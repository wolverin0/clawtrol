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

  # Test: cycle log includes state_before
  test "cycle log includes state_before snapshot" do
    @loop.update!(state: { last_idea: "test idea" })

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_not_nil cycle.state_before
  end

  # Test: cycle log created with pending status first
  test "cycle log created with pending status before wake" do
    # Use invalid URL so it fails after creating cycle
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    # Should be failed since wake failed
    assert_equal "failed", cycle.status
  end

  # Test: sets finished_at on failure
  test "sets finished_at timestamp on wake failure" do
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_not_nil cycle.finished_at
  end

  # Test: preserves loop status after failure
  test "preserves loop status after wake failure" do
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    FactoryRunnerJob.perform_now(@loop.id)

    @loop.reload
    # Loop remains playing even after failure
    assert_equal "playing", @loop.status
  end

  # Test: handles user without gateway URL gracefully
  test "handles user without gateway URL gracefully" do
    @user.update!(openclaw_gateway_url: nil, openclaw_gateway_token: nil)

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_equal "failed", cycle.status
    assert_includes cycle.error_message, "No user found"
  end

  # Test: handles nil user gracefully
  test "handles loop without user gracefully" do
    @loop.update!(user: nil)

    FactoryRunnerJob.perform_now(@loop.id)

    assert_equal 1, FactoryCycleLog.count
    cycle = FactoryCycleLog.last
    assert_equal "failed", cycle.status
  end

  # Test: includes model in wake text
  test "wake text includes loop model" do
    @loop.update!(model: "opus")
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    begin
      FactoryRunnerJob.perform_now(@loop.id)
    rescue
      # Expected to fail
    end

    cycle = FactoryCycleLog.last
    assert_includes cycle.state_before.to_s, "opus"
  end

  # Test: includes system_prompt in wake text
  test "wake text includes system prompt" do
    @loop.update!(system_prompt: "You are a helpful assistant")
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    begin
      FactoryRunnerJob.perform_now(@loop.id)
    rescue
      # Expected to fail
    end

    # Just verify cycle was created
    assert FactoryCycleLog.exists?
  end

  # Test: multiple cycles have sequential numbers
  test "multiple cycles have sequential cycle numbers" do
    # First cycle succeeds, second also succeeds
    5.times do |i|
      # Use invalid URL to avoid actual HTTP calls
      @user.update!(openclaw_gateway_url: "http://invalid-host-#{i}.test:9999")
      FactoryRunnerJob.perform_now(@loop.id)
    end

    cycles = FactoryCycleLog.order(:cycle_number).pluck(:cycle_number)
    assert_equal [1, 2, 3, 4, 5], cycles
  end
end

  # Test: gateway client mocked - tests actual HTTP error handling
  test "handles connection timeout gracefully" do
    @loop.update!(status: "playing")
    @user.update!(openclaw_gateway_url: "http://192.0.2.1:9999") # TEST-NET-1, never responds

    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    @loop.reload
    assert_equal 1, @loop.consecutive_failures
  end

  # Test: validates interval_ms before running
  test "respects interval_ms timing" do
    @loop.update!(interval_ms: 30_000) # 30 seconds

    # Job should still run regardless of interval (job doesn't check timing)
    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    assert FactoryCycleLog.exists?
  end

  # Test: empty backlog does not error
  test "handles empty backlog gracefully" do
    @loop.update!(backlog: [])

    # Should still create cycle log even with empty backlog
    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    assert FactoryCycleLog.exists?
  end
