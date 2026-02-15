# frozen_string_literal: true

require "test_helper"

class RunnerLeaseTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
    @now = Time.current
  end

  # --- Validations ---

  test "valid lease" do
    lease = build_lease
    assert lease.valid?
  end

  test "requires lease_token" do
    lease = build_lease(lease_token: nil)
    assert_not lease.valid?
    assert_includes lease.errors[:lease_token], "can't be blank"
  end

  test "requires unique lease_token" do
    lease1 = build_lease(lease_token: "unique-token-123")
    lease1.save!
    lease2 = build_lease(lease_token: "unique-token-123")
    assert_not lease2.valid?
    assert lease2.errors[:lease_token].any?
  end

  test "requires started_at" do
    lease = build_lease(started_at: nil)
    assert_not lease.valid?
    assert_includes lease.errors[:started_at], "can't be blank"
  end

  test "requires last_heartbeat_at" do
    lease = build_lease(last_heartbeat_at: nil)
    assert_not lease.valid?
    assert_includes lease.errors[:last_heartbeat_at], "can't be blank"
  end

  test "requires expires_at" do
    lease = build_lease(expires_at: nil)
    assert_not lease.valid?
    assert_includes lease.errors[:expires_at], "can't be blank"
  end

  # --- active? ---

  test "active? returns true for non-released non-expired lease" do
    lease = build_lease
    assert lease.active?
  end

  test "active? returns false when released" do
    lease = build_lease(released_at: @now)
    assert_not lease.active?
  end

  test "active? returns false when expired" do
    lease = build_lease(expires_at: 1.minute.ago)
    assert_not lease.active?
  end

  # --- heartbeat! ---

  test "heartbeat! extends expiration" do
    lease = build_lease(expires_at: 1.minute.from_now)
    lease.save!

    travel_to 5.minutes.from_now do
      lease.heartbeat!
      assert lease.expires_at > Time.current
      assert_in_delta Time.current, lease.last_heartbeat_at, 2.seconds
    end
  end

  # --- release! ---

  test "release! sets released_at" do
    lease = build_lease
    lease.save!
    assert_nil lease.released_at

    lease.release!
    assert_not_nil lease.released_at
    assert_not lease.active?
  end

  # --- Scopes ---

  test "active scope excludes released leases" do
    # Use different tasks to avoid unique constraint on (task_id) for active leases
    task_two = tasks(:two)

    active = build_lease(lease_token: "active-1")
    active.save!

    released = build_lease(task: task_two, lease_token: "released-1", released_at: @now)
    released.save!

    results = RunnerLease.active
    assert_includes results, active
    assert_not_includes results, released
  end

  test "expired scope finds expired leases" do
    # Use different tasks to avoid unique constraint on (task_id) for active leases
    task_two = tasks(:two)

    expired = build_lease(lease_token: "expired-1", expires_at: 1.minute.ago)
    expired.save!

    fresh = build_lease(task: task_two, lease_token: "fresh-1")
    fresh.save!

    results = RunnerLease.expired
    assert_includes results, expired
    assert_not_includes results, fresh
  end

  # --- create_for_task! ---

  test "create_for_task! creates lease with correct defaults" do
    lease = RunnerLease.create_for_task!(task: @task, agent_name: "Otacon", source: "test")
    assert lease.persisted?
    assert_equal "Otacon", lease.agent_name
    assert_equal "test", lease.source
    assert lease.active?
    assert_equal 48, lease.lease_token.length # SecureRandom.hex(24)
  end

  test "create_for_task! releases expired leases first" do
    # Create an expired lease manually
    expired = build_lease(expires_at: 1.minute.ago)
    expired.save!(validate: false) # skip unique constraint check since it's "active" in DB sense

    # Should succeed because expired lease gets released first
    new_lease = RunnerLease.create_for_task!(task: @task, agent_name: "Agent", source: "test")
    assert new_lease.persisted?
    assert expired.reload.released_at.present?
  end

  test "create_for_task! raises LeaseConflictError for active lease" do
    RunnerLease.create_for_task!(task: @task, agent_name: "Agent1", source: "test")

    assert_raises RunnerLease::LeaseConflictError do
      RunnerLease.create_for_task!(task: @task, agent_name: "Agent2", source: "test")
    end
  end

  # --- LEASE_DURATION ---

  test "LEASE_DURATION is 15 minutes" do
    assert_equal 15.minutes, RunnerLease::LEASE_DURATION
  end

  private

  def build_lease(**overrides)
    defaults = {
      task: @task,
      lease_token: SecureRandom.hex(24),
      agent_name: "Otacon",
      source: "test",
      started_at: @now,
      last_heartbeat_at: @now,
      expires_at: @now + RunnerLease::LEASE_DURATION
    }
    RunnerLease.new(defaults.merge(overrides))
  end
end
