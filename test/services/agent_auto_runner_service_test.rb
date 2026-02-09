require "test_helper"

class AgentAutoRunnerServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
  end

  class FakeGatewayClient
    cattr_accessor :spawns, default: []

    def initialize(_user)
    end

    def spawn_session!(model:, prompt:)
      self.class.spawns << { model: model, prompt: prompt }
      { child_session_key: "agent:main:subagent:FAKE-KEY", session_id: "FAKE-SESSION-ID" }
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
      AgentAutoRunnerService.new(openclaw_gateway_client: FakeGatewayClient, cache: cache).run!
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
      AgentAutoRunnerService.new(openclaw_gateway_client: FakeGatewayClient, cache: cache).run!
      assert_equal "up_next", task.reload.status

      notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "runner_lease_missing")
      assert notif.present?, "expected a runner_lease_missing notification"
    end

    assert_equal "up_next", task.reload.status
  end

  test "auto-pull claims + spawns the top eligible up_next task and links session" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    task = Task.create!(
      user: user,
      board: board,
      name: "Up next",
      description: "Do the thing",
      status: :up_next,
      assigned_to_agent: false,
      blocked: false,
      model: "gemini",
      validation_command: "bin/rails test"
    )

    FakeGatewayClient.spawns = []

    cache = ActiveSupport::Cache::MemoryStore.new
    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      AgentAutoRunnerService.new(openclaw_gateway_client: FakeGatewayClient, cache: cache).run!

      task.reload
      assert task.assigned_to_agent?
      assert_equal "in_progress", task.status
      assert task.agent_claimed_at.present?
      assert task.runner_lease_active?, "expected an active runner lease"
      assert_equal 1, task.runner_leases.where(released_at: nil).count
      assert_equal "agent:main:subagent:FAKE-KEY", task.agent_session_key
      assert_equal "FAKE-SESSION-ID", task.agent_session_id
    end

    assert_equal 1, FakeGatewayClient.spawns.length
    spawn = FakeGatewayClient.spawns.first
    assert_equal "gemini3", spawn[:model], "expected task.model=gemini to map to OpenClaw gemini3"
    assert_includes spawn[:prompt], "Do the thing"
    assert_includes spawn[:prompt], "bin/rails test"

    notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "auto_pull_spawned")
    assert notif.present?, "expected an auto_pull_spawned notification"
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

    FakeGatewayClient.spawns = []
    cache = ActiveSupport::Cache::MemoryStore.new

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 16, 0, 0) do
      AgentAutoRunnerService.new(openclaw_gateway_client: FakeGatewayClient, cache: cache).run!
    end

    assert_equal 0, FakeGatewayClient.spawns.length
    assert_equal "up_next", nightly.reload.status
  end

  test "spawn failures revert claim and create an error notification" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    task = Task.create!(
      user: user,
      board: board,
      name: "Up next",
      status: :up_next,
      blocked: false
    )

    failing_client = Class.new do
      def initialize(_user)
      end

      def spawn_session!(*)
        raise "boom"
      end
    end

    cache = ActiveSupport::Cache::MemoryStore.new
    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      AgentAutoRunnerService.new(openclaw_gateway_client: failing_client, cache: cache).run!

      task.reload
      assert_equal "up_next", task.status
      assert_nil task.agent_claimed_at
      assert_equal 0, task.runner_leases.where(released_at: nil).count, "expected lease to be released on spawn failure"
    end

    notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "auto_pull_error")
    assert notif.present?, "expected an auto_pull_error notification"
  end
end
