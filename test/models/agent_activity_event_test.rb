# frozen_string_literal: true

require "test_helper"

class AgentActivityEventTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  test "enforces run_id + seq idempotency" do
    AgentActivityEvent.create!(
      task: @task,
      run_id: "run-a",
      source: "hook",
      level: "info",
      event_type: "heartbeat",
      message: "tick",
      seq: 1
    )

    duplicate = AgentActivityEvent.new(
      task: @task,
      run_id: "run-a",
      source: "hook",
      level: "info",
      event_type: "heartbeat",
      message: "tick2",
      seq: 1
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:run_id], "has already been taken"
  end

  test "ordered scope sorts by created_at then seq" do
    older = AgentActivityEvent.create!(task: @task, run_id: "run-b", source: "hook", level: "info", event_type: "message", message: "older", seq: 2, created_at: 2.minutes.ago)
    newer = AgentActivityEvent.create!(task: @task, run_id: "run-b", source: "hook", level: "info", event_type: "message", message: "newer", seq: 1, created_at: 1.minute.ago)

    assert_equal [older.id, newer.id], AgentActivityEvent.for_task(@task.id).ordered.pluck(:id)
  end
end
