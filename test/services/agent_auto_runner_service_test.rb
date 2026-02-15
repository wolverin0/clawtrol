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
end
