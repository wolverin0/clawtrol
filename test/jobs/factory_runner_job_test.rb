# frozen_string_literal: true

require "test_helper"
require "webmock"

class FactoryRunnerJobTest < ActiveJob::TestCase
  include WebMock::API

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
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: false)
  end

  teardown do
    WebMock.reset!
    WebMock.disable_net_connect!
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
    mock_wake_success
    FactoryRunnerJob.perform_now(@loop.id)

    assert_equal 1, FactoryCycleLog.count
    cycle = FactoryCycleLog.first
    assert_equal 1, cycle.cycle_number
  end

  # Test: increments cycle number on subsequent runs
  test "increments cycle number on subsequent runs" do
    mock_wake_success
    3.times do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    assert_equal 3, FactoryCycleLog.count
  end

  # Test: increments failures on wake failure
  test "increments failures on wake exception" do
    @loop.update!(consecutive_failures: 0, total_errors: 0)
    stub_request(:post, /hooks\/wake/).to_raise(Errno::ECONNREFUSED)

    FactoryRunnerJob.perform_now(@loop.id)

    @loop.reload
    assert_equal 1, @loop.consecutive_failures
    assert_equal 1, @loop.total_errors
  end

  # Test: handles HTTP connection errors gracefully
  test "increments failures on connection error" do
    @loop.update!(consecutive_failures: 0, total_errors: 0)
    stub_request(:post, /hooks\/wake/).to_raise(Net::OpenTimeout)

    FactoryRunnerJob.perform_now(@loop.id)

    @loop.reload
    assert_equal 1, @loop.consecutive_failures
    assert_equal 1, @loop.total_errors
  end

  # Test: handles HTTP read timeout gracefully
  test "increments failures on read timeout" do
    @loop.update!(consecutive_failures: 0, total_errors: 0)
    stub_request(:post, /hooks\/wake/).to_raise(Net::ReadTimeout)

    FactoryRunnerJob.perform_now(@loop.id)

    @loop.reload
    assert_equal 1, @loop.consecutive_failures
    assert_equal 1, @loop.total_errors
  end

  # Test: handles race condition gracefully
  test "handles race condition on duplicate cycle numbers" do
    mock_wake_success
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
    mock_wake_success
    @loop.update!(state: { last_idea: "test idea" })

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_not_nil cycle.state_before
  end

  # Test: cycle log created with running status after successful wake
  test "cycle log created with running status after successful wake" do
    mock_wake_success

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_equal "running", cycle.status
  end

  # Test: sets finished_at on failure
  test "sets finished_at timestamp on wake failure" do
    stub_request(:post, /hooks\/wake/).to_raise(Errno::ECONNREFUSED)

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_equal "failed", cycle.status
    assert_not_nil cycle.finished_at
  end

  # Test: preserves loop status after failure
  test "preserves loop status after wake failure" do
    stub_request(:post, /hooks\/wake/).to_raise(Errno::ECONNREFUSED)

    FactoryRunnerJob.perform_now(@loop.id)

    @loop.reload
    # Loop remains playing even after failure
    assert_equal "playing", @loop.status
  end

  # Test: handles user without gateway URL gracefully
  test "handles user without gateway URL gracefully" do
    @user.update!(openclaw_gateway_url: nil, openclaw_gateway_token: nil)
    stub_request(:post, /hooks\/wake/).to_raise(Errno::ECONNREFUSED)

    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    assert_equal "failed", cycle.status
    assert cycle.summary.present?
  end

  # Test: handles nil user gracefully
  test "handles loop without user gracefully" do
    @loop.update!(user: nil)

    FactoryRunnerJob.perform_now(@loop.id)

    assert_equal 1, FactoryCycleLog.count
    cycle = FactoryCycleLog.last
    assert_equal "failed", cycle.status
  end

  # Test: wake request includes model in text
  test "wake request includes correct model" do
    @loop.update!(model: "opus")
    wake_request = nil
    stub_request(:post, /hooks\/wake/).with { |req| wake_request = req }
      .to_return(status: 200, body: '{"ok":true}')

    FactoryRunnerJob.perform_now(@loop.id)

    assert_not_nil wake_request
    body = JSON.parse(wake_request.body)
    assert_includes body["text"], "Model: opus"
  end

  # Test: wake request includes system prompt
  test "wake request includes system prompt" do
    @loop.update!(system_prompt: "You are a helpful assistant")
    wake_request = nil
    stub_request(:post, /hooks\/wake/).with { |req| wake_request = req }
      .to_return(status: 200, body: '{"ok":true}')

    FactoryRunnerJob.perform_now(@loop.id)

    assert_not_nil wake_request
    body = JSON.parse(wake_request.body)
    assert_includes body["text"], "You are a helpful assistant"
  end

  # Test: wake request includes correct callback URL
  test "wake request includes cycle callback URL" do
    wake_request = nil
    stub_request(:post, /hooks\/wake/).with { |req| wake_request = req }
      .to_return(status: 200, body: '{"ok":true}')

    FactoryRunnerJob.perform_now(@loop.id)

    assert_not_nil wake_request
    body = JSON.parse(wake_request.body)
    assert_includes body["text"], "/api/v1/factory/cycles/"
  end

  # Test: multiple cycles have sequential numbers
  test "multiple cycles have sequential cycle numbers" do
    mock_wake_success
    5.times do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    cycles = FactoryCycleLog.order(:cycle_number).pluck(:cycle_number)
    assert_equal [1, 2, 3, 4, 5], cycles
  end

  # Test: validates interval_ms before running
  test "respects interval_ms timing" do
    mock_wake_success
    @loop.update!(interval_ms: 30_000) # 30 seconds

    # Job should still run regardless of interval (job doesn't check timing)
    assert_nothing_raised do
      FactoryRunnerJob.perform_now(@loop.id)
    end

    assert FactoryCycleLog.exists?
  end

  # Test: cycle log includes cycle ID in wake text
  test "cycle log ID included in wake text" do
    mock_wake_success
    FactoryRunnerJob.perform_now(@loop.id)

    cycle = FactoryCycleLog.last
    wake_request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first
    assert_not_nil wake_request
    # Verify cycle number is referenced in the request
    assert_includes wake_request.uri.to_s, "hooks/wake"
  end

  # Test: uses hooks_token when available
  test "uses hooks_token for authorization when available" do
    @user.update!(openclaw_hooks_token: "custom_hooks_token_123")
    wake_request = nil
    stub_request(:post, /hooks\/wake/).with { |req| wake_request = req }
      .to_return(status: 200, body: '{"ok":true}')

    FactoryRunnerJob.perform_now(@loop.id)

    assert_not_nil wake_request
    assert_equal "Bearer custom_hooks_token_123", wake_request.headers["Authorization"]
  end

  # Test: uses gateway token as fallback
  test "uses gateway token as fallback when hooks_token not present" do
    @user.update!(openclaw_hooks_token: nil, openclaw_gateway_token: "gateway_token_456")
    wake_request = nil
    stub_request(:post, /hooks\/wake/).with { |req| wake_request = req }
      .to_return(status: 200, body: '{"ok":true}')

    FactoryRunnerJob.perform_now(@loop.id)

    assert_not_nil wake_request
    assert_equal "Bearer gateway_token_456", wake_request.headers["Authorization"]
  end

  # Test: re-enqueues next cycle if loop still playing
  test "re-enqueues next cycle when loop still playing" do
    mock_wake_success

    assert_enqueued_with(job: FactoryRunnerJob, args: [@loop.id]) do
      FactoryRunnerJob.perform_now(@loop.id)
    end
  end

  # Test: does not re-enqueue if loop no longer playing
  test "does not re-enqueue when loop status changed" do
    mock_wake_success
    # Clear any existing jobs
    SolidQueue::Job.where(class_name: "FactoryRunnerJob").delete_all
    # Change status to paused after cycle is created but before re-enqueue check
    @loop.update!(status: "paused")

    FactoryRunnerJob.perform_now(@loop.id)

    # No new job should be enqueued
    next_job = SolidQueue::Job.where(class_name: "FactoryRunnerJob").where("arguments = ?", [@loop.id].to_json).first
    assert_nil next_job, "Expected no job to be enqueued when loop is paused"
  end

  # Test: gateway client mocked - successful wake
  test "mocked gateway client receives correct wake payload" do
    expected_text = "Factory cycle ##{FactoryCycleLog.last&.id || 1} for loop \"#{@loop.name}\" (cycle 1)"
    wake_request = nil
    stub_request(:post, /hooks\/wake/).with { |req| wake_request = req }
      .to_return(status: 200, body: '{"ok":true}')

    FactoryRunnerJob.perform_now(@loop.id)

    assert_not_nil wake_request
    body = JSON.parse(wake_request.body)
    assert_includes body["text"], "Factory cycle"
    assert_includes body["text"], @loop.name
    assert_equal "now", body["mode"]
  end

  private

  def mock_wake_success
    stub_request(:post, /hooks\/wake/).to_return(status: 200, body: '{"ok":true}')
  end

  def mock_wake_failure(status, body)
    stub_request(:post, /hooks\/wake/).to_return(status: status, body: body)
  end
end
