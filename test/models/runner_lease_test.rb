# frozen_string_literal: true

require "test_helper"

class RunnerLeaseTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  # === Validations ===

  test "lease_token is required" do
    lease = RunnerLease.new(task: @task)
    assert_not lease.valid?
    assert_includes lease.errors[:lease_token], "can't be blank"
  end

  test "lease_token must be unique" do
    token = "unique-token-123"
    lease1 = RunnerLease.create!(
      task: @task,
      lease_token: token,
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )

    lease2 = RunnerLease.new(
      task: @task,
      lease_token: token,
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )
    assert_not lease2.valid?
    assert_includes lease2.errors[:lease_token], "has already been taken"
  end

  test "started_at is required" do
    lease = RunnerLease.new(task: @task, lease_token: "test")
    assert_not lease.valid?
    assert_includes lease.errors[:started_at], "can't be blank"
  end

  test "last_heartbeat_at is required" do
    lease = RunnerLease.new(task: @task, lease_token: "test")
    assert_not lease.valid?
    assert_includes lease.errors[:last_heartbeat_at], "can't be blank"
  end

  test "expires_at is required" do
    lease = RunnerLease.new(task: @task, lease_token: "test")
    assert_not lease.valid?
    assert_includes lease.errors[:expires_at], "can't be blank"
  end

  # === Associations ===

  test "belongs to task" do
    lease = runner_leases(:one)
    assert_equal @task, lease.task
  end

  # === Scopes ===

  test "active scope returns non-expired, non-released leases" do
    active_lease = RunnerLease.create!(
      task: @task,
      lease_token: "active-lease",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )

    expired_lease = RunnerLease.create!(
      task: @task,
      lease_token: "expired-lease",
      started_at: 1.hour.ago,
      last_heartbeat_at: 1.hour.ago,
      expires_at: 1.hour.ago
    )

    released_lease = RunnerLease.create!(
      task: @task,
      lease_token: "released-lease",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now,
      released_at: Time.current
    )

    assert_includes RunnerLease.active, active_lease
    assert_not_includes RunnerLease.active, expired_lease
    assert_not_includes RunnerLease.active, released_lease
  end

  test "expired scope returns expired, non-released leases" do
    expired_lease = RunnerLease.create!(
      task: @task,
      lease_token: "expired-scope",
      started_at: 1.hour.ago,
      last_heartbeat_at: 1.hour.ago,
      expires_at: 1.hour.ago
    )

    active_lease = RunnerLease.create!(
      task: @task,
      lease_token: "active-scope",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )

    assert_includes RunnerLease.expired, expired_lease
    assert_not_includes RunnerLease.expired, active_lease
  end

  # === Class Methods ===

  test "create_for_task! creates a new lease" do
    lease = RunnerLease.create_for_task!(
      task: @task,
      agent_name: "test-agent",
      source: "api_claim"
    )

    assert_equal @task, lease.task
    assert_equal "test-agent", lease.agent_name
    assert_equal "api_claim", lease.source
    assert_not_nil lease.lease_token
    assert_not_nil lease.started_at
    assert_not_nil lease.last_heartbeat_at
    assert_not_nil lease.expires_at
    assert_nil lease.released_at
  end

  test "create_for_task! releases expired leases first" do
    # Create expired lease
    expired = RunnerLease.create!(
      task: @task,
      lease_token: "expired-create",
      started_at: 1.hour.ago,
      last_heartbeat_at: 1.hour.ago,
      expires_at: 1.hour.ago
    )

    # Create new lease should succeed by releasing expired one
    new_lease = RunnerLease.create_for_task!(
      task: @task,
      agent_name: "new-agent",
      source: "spawn_ready"
    )

    assert_not_nil new_lease
    expired.reload
    assert_not_nil expired.released_at
  end

  test "create_for_task! raises LeaseConflictError for active lease" do
    # Create active lease
    RunnerLease.create!(
      task: @task,
      lease_token: "active-conflict",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )

    # Attempting to create another should fail
    assert_raises(RunnerLease::LeaseConflictError) do
      RunnerLease.create_for_task!(
        task: @task,
        agent_name: "conflict-agent",
        source: "test"
      )
    end
  end

  # === Instance Methods ===

  test "active? returns true for valid active lease" do
    lease = RunnerLease.create!(
      task: @task,
      lease_token: "active-check",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )
    assert lease.active?
  end

  test "active? returns false when released" do
    lease = RunnerLease.create!(
      task: @task,
      lease_token: "released-check",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now,
      released_at: Time.current
    )
    assert_not lease.active?
  end

  test "active? returns false when expired" do
    lease = RunnerLease.create!(
      task: @task,
      lease_token: "expired-check",
      started_at: 1.hour.ago,
      last_heartbeat_at: 1.hour.ago,
      expires_at: 1.hour.ago
    )
    assert_not lease.active?
  end

  test "heartbeat! updates last_heartbeat_at and extends expires_at" do
    original_expires = 5.minutes.from_now
    lease = RunnerLease.create!(
      task: @task,
      lease_token: "heartbeat-test",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: original_expires
    )

    travel 5.minutes
    lease.heartbeat!

    lease.reload
    assert lease.last_heartbeat_at > 6.minutes.ago
    assert lease.expires_at > original_expires
  end

  test "release! sets released_at timestamp" do
    lease = RunnerLease.create!(
      task: @task,
      lease_token: "release-test",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 15.minutes.from_now
    )

    assert_nil lease.released_at
    lease.release!
    assert_not_nil lease.released_at
    assert_not lease.active?
  end

end
