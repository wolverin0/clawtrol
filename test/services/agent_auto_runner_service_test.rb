# frozen_string_literal: true

require "test_helper"

class AgentAutoRunnerServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
  end

  def with_stubbed_runner_lease_create!(raises_message: "boom")
    singleton = class << RunnerLease; self; end
    original = singleton.instance_method(:create!)

    singleton.define_method(:create!) do |*args, **kwargs, &blk|
      raise raises_message
    end

    yield
  ensure
    singleton.define_method(:create!, original)
  end

  class FakeWebhookService
    cattr_accessor :wakes, default: []

    def initialize(_user)
    end

    def notify_auto_pull_ready(task)
      self.class.wakes << { task_id: task.id, name: task.name }
      true
    end

    def notify_auto_pull_ready_with_pipeline(task)
      self.class.wakes << { task_id: task.id, name: task.name, pipeline: true }
      true
    end
  end

  test "demotes in_progress tasks with expired runner leases" do
    user = User.create!(
      email_address: "auto_runner_demote_#{SecureRandom.hex(4)}@example.test",
      password: "password123",
      password_confirmation: "password123",
      agent_auto_mode: true,
      openclaw_gateway_url: "http://example.test",
      openclaw_gateway_token: "tok"
    )

    board = Board.create!(user: user, name: "Test Board")

    stuck = Task.create!(
      user: user,
      board: board,
      name: "Stuck task",
      status: :up_next,
      assigned_to_agent: true
    )

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      now = Time.current

      lease = RunnerLease.create!(
        task: stuck,
        agent_name: "Test Agent",
        lease_token: SecureRandom.hex(16),
        source: "test",
        started_at: now - 20.minutes,
        last_heartbeat_at: now - 20.minutes,
        expires_at: now + 1.minute
      )

      stuck.update!(status: :in_progress)
      lease.update_columns(expires_at: now - 1.minute)

      cache = ActiveSupport::Cache::MemoryStore.new
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal "up_next", stuck.reload.status

    assert stuck.runner_leases.where(released_at: nil).none?, "expected lease to be released"
  end

  test "demotes in_progress tasks missing an active lease even if a released lease exists" do
    user = User.create!(
      email_address: "auto_runner_missing_lease_#{SecureRandom.hex(4)}@example.test",
      password: "password123",
      password_confirmation: "password123",
      agent_auto_mode: true,
      openclaw_gateway_url: "http://example.test",
      openclaw_gateway_token: "tok"
    )

    board = Board.create!(user: user, name: "Test Board")

    task = Task.create!(
      user: user,
      board: board,
      name: "Missing lease task",
      status: :up_next,
      assigned_to_agent: true
    )

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      now = Time.current

      # Historical lease exists but is already released; it should not prevent demotion.
      RunnerLease.create!(
        task: task,
        agent_name: "Test Agent",
        lease_token: SecureRandom.hex(16),
        source: "test",
        started_at: now - 40.minutes,
        last_heartbeat_at: now - 40.minutes,
        expires_at: now - 30.minutes,
        released_at: now - 30.minutes
      )

      # Simulate DB drift: task ended up in_progress without an active lease.
      task.update_columns(status: Task.statuses[:in_progress], updated_at: 20.minutes.ago)

      cache = ActiveSupport::Cache::MemoryStore.new
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
      assert_equal "up_next", task.reload.status

      notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "runner_lease_missing")
      assert notif.present?, "expected a runner_lease_missing notification"
    end

    assert_equal "up_next", task.reload.status
  end

  test "auto-pull wakes the top eligible up_next task (assigned) without claiming it" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    task = Task.create!(
      user: user,
      board: board,
      name: "Up next",
      description: "Do the thing",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false,
      model: "gemini",
      validation_command: "bin/rails test"
    )

    FakeWebhookService.wakes = []

    cache = ActiveSupport::Cache::MemoryStore.new
    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!

      task.reload
      assert task.assigned_to_agent?
      assert_equal "up_next", task.status
      assert_nil task.agent_claimed_at
      assert_equal 0, task.runner_leases.where(released_at: nil).count
      assert_nil task.agent_session_key
      assert_nil task.agent_session_id

      # Cooldown: should not wake again immediately.
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal 1, FakeWebhookService.wakes.length
    wake = FakeWebhookService.wakes.first
    assert_equal task.id, wake[:task_id]

    notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "auto_pull_ready")
    assert notif.present?, "expected an auto_pull_ready notification"
  end

  test "nightly tasks are not auto-pulled outside the nightly window" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    nightly = Task.create!(
      user: user,
      board: board,
      name: "Nightly task",
      status: :up_next,
      blocked: false,
      nightly: true
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 16, 0, 0) do
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal 0, FakeWebhookService.wakes.length
    assert_equal "up_next", nightly.reload.status
  end

  # --- Zombie detection ---

  test "notifies about zombie tasks stale for over 30 minutes" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      zombie = Task.create!(
        user: user,
        board: board,
        name: "Zombie task",
        status: :up_next,
        assigned_to_agent: true
      )

      # Need an active lease so it doesn't get demoted
      RunnerLease.create!(
        task: zombie,
        agent_name: "Ghost Agent",
        lease_token: SecureRandom.hex(16),
        source: "test",
        started_at: 45.minutes.ago,
        last_heartbeat_at: 5.minutes.ago,
        expires_at: 10.minutes.from_now
      )

      # Bypass validation to set in_progress + stale timestamps
      zombie.update_columns(
        status: Task.statuses[:in_progress],
        agent_claimed_at: 60.minutes.ago,
        updated_at: 45.minutes.ago
      )

      stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
      assert stats[:zombie_tasks] > 0, "expected zombies, got stats=#{stats.inspect}"

      notif = Notification.order(created_at: :desc).find_by(user: user, event_type: "zombie_detected")
      assert notif.present?, "expected a zombie_detected notification"
      assert_match(/zombie/i, notif.message)
    end
  end

  test "zombie notifications respect cooldown" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      zombie = Task.create!(
        user: user,
        board: board,
        name: "Zombie task cooldown",
        status: :up_next,
        assigned_to_agent: true
      )

      RunnerLease.create!(
        task: zombie,
        agent_name: "Ghost Agent",
        lease_token: SecureRandom.hex(16),
        source: "test",
        started_at: 45.minutes.ago,
        last_heartbeat_at: 5.minutes.ago,
        expires_at: 10.minutes.from_now
      )

      zombie.update_columns(
        status: Task.statuses[:in_progress],
        agent_claimed_at: 60.minutes.ago,
        updated_at: 45.minutes.ago
      )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      # First run: should notify
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
      count_after_first = Notification.where(user: user, event_type: "zombie_detected").count

      # Second run immediately: cooldown should prevent duplicate
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
      count_after_second = Notification.where(user: user, event_type: "zombie_detected").count

      assert_equal count_after_first, count_after_second, "zombie notification should not duplicate within cooldown"
    end
  end

  # --- User filtering ---

  test "skips users without gateway config" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: nil, openclaw_gateway_token: nil)

    board = boards(:one)
    Task.create!(
      user: user,
      board: board,
      name: "Should not wake",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    assert_equal 0, stats[:users_woken]
    assert_equal 0, FakeWebhookService.wakes.length
  end

  test "skips users with agent_auto_mode disabled" do
    user = users(:one)
    user.update!(agent_auto_mode: false, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    Task.create!(
      user: user,
      board: board,
      name: "Auto mode off",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    assert_equal 0, stats[:users_considered]
    assert_equal 0, FakeWebhookService.wakes.length
  end

  # --- Blocked/recurring exclusion ---

  test "does not wake for blocked tasks" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    Task.create!(
      user: user,
      board: board,
      name: "Blocked task",
      status: :up_next,
      assigned_to_agent: true,
      blocked: true
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal 0, FakeWebhookService.wakes.length
  end

  test "does not wake for recurring template tasks" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    Task.create!(
      user: user,
      board: board,
      name: "Recurring template",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false,
      recurring: true,
      parent_task_id: nil
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal 0, FakeWebhookService.wakes.length
  end

  # --- Does not wake if agent is already working ---

  test "does not wake if user has active lease on in_progress task" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    working = Task.create!(
      user: user,
      board: board,
      name: "Currently running",
      status: :up_next,
      assigned_to_agent: true
    )

    RunnerLease.create!(
      task: working,
      agent_name: "Active Agent",
      lease_token: SecureRandom.hex(16),
      source: "test",
      started_at: 2.minutes.ago,
      last_heartbeat_at: 1.minute.ago,
      expires_at: 13.minutes.from_now
    )

    # Bypass validation to set in_progress
    working.update_columns(status: Task.statuses[:in_progress])

    waiting = Task.create!(
      user: user,
      board: board,
      name: "Waiting task",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
      assert_equal 0, stats[:users_woken]
    end

    assert_equal 0, FakeWebhookService.wakes.length
  end

  # --- auto_pull_blocked ---

  test "does not wake for auto_pull_blocked tasks" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    Task.create!(
      user: user,
      board: board,
      name: "Pull blocked",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false,
      auto_pull_blocked: true
    )

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal 0, FakeWebhookService.wakes.length
  end

  # --- Failure cooldown ---

  test "does not wake for tasks with recent auto_pull errors" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      Task.create!(
        user: user,
        board: board,
        name: "Recently errored",
        status: :up_next,
        assigned_to_agent: true,
        blocked: false,
        auto_pull_last_error_at: 2.minutes.ago
      )

      AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
    end

    assert_equal 0, FakeWebhookService.wakes.length
  end

  test "wakes for tasks with old auto_pull errors past cooldown" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      Task.create!(
        user: user,
        board: board,
        name: "Old error task",
        status: :up_next,
        assigned_to_agent: true,
        blocked: false,
        auto_pull_last_error_at: 10.minutes.ago
      )

      stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
      assert_equal 1, stats[:users_woken], "stats=#{stats.inspect}"
    end

    assert_equal 1, FakeWebhookService.wakes.length
  end

  # --- Stats reporting ---

  test "run! returns accurate stats hash" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!

      assert_kind_of Hash, stats
      assert stats.key?(:users_considered)
      assert stats.key?(:users_woken)
      assert stats.key?(:tasks_demoted)
      assert stats.key?(:zombie_tasks)
      assert stats.key?(:pipeline_processed)
      assert_kind_of Integer, stats[:users_considered]
    end
  end
end
