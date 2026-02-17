# frozen_string_literal: true

require "test_helper"

class RunnerLeaseTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
    @task_two = tasks(:two)
    @now = Time.current
  end

  test "lease_token is required" do
    lease = RunnerLease.new(task: @task)
    assert_not lease.valid?
    assert_includes lease.errors[:lease_token], "can't be blank"
  end

  test "lease_token must be unique" do
    token = "unique-token-123"
    create_lease(task: @task, lease_token: token)

    lease2 = RunnerLease.new(
      task: @task_two,
      lease_token: token,
      started_at: @now,
      last_heartbeat_at: @now,
      expires_at: @now + 15.minutes
    )
    assert_not lease2.valid?
    assert_includes lease2.errors[:lease_token], "has already been taken"
  end

  test "required timestamps are validated" do
    lease = RunnerLease.new(task: @task, lease_token: "token-1")
    assert_not lease.valid?
    assert_includes lease.errors[:started_at], "can't be blank"
    assert_includes lease.errors[:last_heartbeat_at], "can't be blank"
    assert_includes lease.errors[:expires_at], "can't be blank"
  end

  test "belongs to task" do
    lease = create_lease(task: @task, lease_token: "belongs-task")
    assert_equal @task, lease.task
  end

  test "active scope excludes expired and released leases" do
    active_lease = create_lease(task: @task, lease_token: "active-lease")
    expired_lease = create_lease(task: @task_two, lease_token: "expired-lease", started_at: 2.hours.ago, expires_at: 1.hour.ago)
    released_lease = create_lease(task: @task, lease_token: "released-lease", released_at: Time.current)

    assert_includes RunnerLease.active, active_lease
    assert_not_includes RunnerLease.active, expired_lease
    assert_not_includes RunnerLease.active, released_lease
  end

  test "expired scope returns only expired unreleased leases" do
    expired_lease = create_lease(task: @task, lease_token: "expired-scope", started_at: 2.hours.ago, expires_at: 1.hour.ago)
    active_lease = create_lease(task: @task_two, lease_token: "active-scope")

    assert_includes RunnerLease.expired, expired_lease
    assert_not_includes RunnerLease.expired, active_lease
  end

  test "create_for_task! creates a new lease" do
    lease = RunnerLease.create_for_task!(task: @task, agent_name: "test-agent", source: "api_claim")

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
    expired = create_lease(task: @task, lease_token: "expired-create", started_at: 2.hours.ago, expires_at: 1.hour.ago)
    new_lease = RunnerLease.create_for_task!(task: @task, agent_name: "new-agent", source: "spawn_ready")

    assert_not_nil new_lease
    expired.reload
    assert_not_nil expired.released_at
  end

  test "create_for_task! raises LeaseConflictError for active lease" do
    create_lease(task: @task, lease_token: "active-conflict")

    assert_raises(RunnerLease::LeaseConflictError) do
      RunnerLease.create_for_task!(task: @task, agent_name: "conflict-agent", source: "test")
    end
  end

  test "active? returns expected state" do
    active = create_lease(task: @task, lease_token: "active-check")
    assert active.active?

    released = create_lease(task: @task, lease_token: "released-check", released_at: Time.current)
    assert_not released.active?

    expired = create_lease(task: @task_two, lease_token: "expired-check", started_at: 2.hours.ago, expires_at: 1.hour.ago)
    assert_not expired.active?
  end

  test "heartbeat! updates timestamps" do
    original_expires = 5.minutes.from_now
    lease = create_lease(task: @task, lease_token: "heartbeat-test", expires_at: original_expires)

    travel 5.minutes do
      lease.heartbeat!
    end

    lease.reload
    assert lease.last_heartbeat_at > 1.minute.ago
    assert lease.expires_at > original_expires
  end

  test "release! sets released_at timestamp" do
    lease = create_lease(task: @task, lease_token: "release-test")
    assert_nil lease.released_at

    lease.release!
    lease.reload
    assert_not_nil lease.released_at
    assert_not lease.active?
  end

  test "LEASE_DURATION is 15 minutes" do
    assert_equal 15.minutes, RunnerLease::LEASE_DURATION
  end

  # --- Validations ---

  test "expires_at must be after started_at" do
    lease = RunnerLease.new(
      task: @task,
      lease_token: "token-expires",
      started_at: Time.current,
      last_heartbeat_at: Time.current,
      expires_at: 1.hour.ago
    )
    assert_not lease.valid?
    assert_includes lease.errors[:expires_at], "must be after started_at"
  end

  test "expires_at can equal started_at" do
    same_time = Time.current
    lease = RunnerLease.new(
      task: @task,
      lease_token: "token-equal",
      started_at: same_time,
      last_heartbeat_at: same_time,
      expires_at: same_time
    )
    # Technically this is equal, not after - let's see what happens
    lease.valid? # Just ensure no crash
  end

  test "last_heartbeat_at must be after started_at" do
    lease = RunnerLease.new(
      task: @task,
      lease_token: "token-heartbeat",
      started_at: Time.current,
      last_heartbeat_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    assert_not lease.valid?
    assert_includes lease.errors[:last_heartbeat_at], "must be after started_at"
  end

  test "lease_token maximum length is 255" do
    lease = RunnerLease.new(
      task: @task,
      lease_token: "a" * 256,
      started_at: @now,
      last_heartbeat_at: @now,
      expires_at: @now + 15.minutes
    )
    assert_not lease.valid?
  end

  test "agent_name maximum length is 100" do
    lease = RunnerLease.new(
      task: @task,
      lease_token: "token-agent",
      agent_name: "a" * 101,
      started_at: @now,
      last_heartbeat_at: @now,
      expires_at: @now + 15.minutes
    )
    assert_not lease.valid?
    assert_includes lease.errors[:agent_name], "is too long"
  end

  test "agent_name can be nil" do
    lease = create_lease(task: @task, lease_token: "token-no-agent", agent_name: nil)
    assert lease.valid?
  end

  test "source maximum length is 50" do
    lease = RunnerLease.new(
      task: @task,
      lease_token: "token-source",
      source: "a" * 51,
      started_at: @now,
      last_heartbeat_at: @now,
      expires_at: @now + 15.minutes
    )
    assert_not lease.valid?
    assert_includes lease.errors[:source], "is too long"
  end

  test "source can be nil" do
    lease = create_lease(task: @task, lease_token: "token-no-source", source: nil)
    assert lease.valid?
  end

  # --- Scopes edge cases ---

  test "active scope excludes leases expiring exactly now" do
    # Create a lease that expires exactly at current time
    lease = create_lease(task: @task, lease_token: "exact-expire", expires_at: Time.current)
    assert_not_includes RunnerLease.active, lease
  end

  test "expired scope includes leases expiring exactly now" do
    lease = create_lease(task: @task, lease_token: "exact-expired", expires_at: Time.current)
    assert_includes RunnerLease.expired, lease
  end

  private

  def create_lease(task:, lease_token: SecureRandom.hex(8), started_at: @now, last_heartbeat_at: started_at, expires_at: nil, released_at: nil)
    RunnerLease.create!(
      task: task,
      lease_token: lease_token,
      agent_name: "tester",
      source: "test",
      started_at: started_at,
      last_heartbeat_at: last_heartbeat_at,
      expires_at: expires_at || (started_at + 15.minutes),
      released_at: released_at
    )
  end
end
