require "test_helper"

class AgentAutoRunnerServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "demotes fake in_progress tasks (no session, no claim) after grace period" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)

    stuck = Task.create!(
      user: user,
      board: board,
      name: "Stuck task",
      status: :in_progress,
      assigned_to_agent: true
    )
    stuck.update_columns(updated_at: 11.minutes.ago)

    fake_openclaw = Class.new do
      def initialize(_user)
      end

      def notify_task_assigned(_task)
        true
      end
    end

    cache = ActiveSupport::Cache::MemoryStore.new
    stats = AgentAutoRunnerService.new(openclaw_webhook_service: fake_openclaw, cache: cache).run!
    assert stats[:tasks_demoted] >= 1

    assert_equal "up_next", stuck.reload.status

    notif = Notification.order(created_at: :desc).find_by(task: stuck, event_type: "zombie_task")
    assert notif.present?, "expected a zombie_task notification"
  end

  test "wakes OpenClaw when up_next work exists and rate-limits wake calls" do
    user = users(:one)
    user.update!(agent_auto_mode: true, openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    board = boards(:one)
    task = Task.create!(
      user: user,
      board: board,
      name: "Up next",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false
    )

    fake_openclaw = Class.new do
      cattr_accessor :calls, default: 0

      def initialize(_user)
      end

      def notify_task_assigned(_task)
        self.class.calls += 1
        true
      end
    end

    cache = ActiveSupport::Cache::MemoryStore.new

    fake_openclaw.calls = 0
    AgentAutoRunnerService.new(openclaw_webhook_service: fake_openclaw, cache: cache).run!
    AgentAutoRunnerService.new(openclaw_webhook_service: fake_openclaw, cache: cache).run!
    calls = fake_openclaw.calls

    assert_equal 1, calls, "expected wake to be rate-limited"

    notif = Notification.order(created_at: :desc).find_by(task: task, event_type: "auto_runner")
    assert notif.present?, "expected an auto_runner notification"
  end
end
