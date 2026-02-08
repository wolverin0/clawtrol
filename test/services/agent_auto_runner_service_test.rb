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

  test "demotes fake in_progress tasks (no session, no claim) after grace period" do
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
      status: :in_progress,
      assigned_to_agent: true
    )
    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      stuck.update_columns(updated_at: 20.minutes.ago)

      cache = ActiveSupport::Cache::MemoryStore.new
      stats = AgentAutoRunnerService.new(openclaw_gateway_client: FakeGatewayClient, cache: cache).run!
      assert stats[:tasks_demoted] >= 1
    end

    assert_equal "up_next", stuck.reload.status

    notif = Notification.order(created_at: :desc).find_by(task: stuck, event_type: "zombie_task")
    assert notif.present?, "expected a zombie_task notification"
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
    end

    task.reload
    assert task.assigned_to_agent?
    assert_equal "in_progress", task.status
    assert task.agent_claimed_at.present?
    assert_equal "agent:main:subagent:FAKE-KEY", task.agent_session_key
    assert_equal "FAKE-SESSION-ID", task.agent_session_id

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
    end

    task.reload
    assert_equal "up_next", task.status
    assert_nil task.agent_claimed_at

    notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "auto_pull_error")
    assert notif.present?, "expected an auto_pull_error notification"
  end
end
