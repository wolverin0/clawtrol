# frozen_string_literal: true

require "test_helper"

class RuntimeEventsIngestionServiceTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  test "ingests runtime tool_call events with input summary" do
    result = RuntimeEventsIngestionService.call(
      task: @task,
      run_id: "run-rt-2",
      map_id: "task_#{@task.id}",
      events: [
        {
          type: "tool_call",
          seq: 1,
          tool_name: "Write",
          input: { command: "printf hello", cwd: "/app", path: "README.md" }
        }
      ]
    )

    assert_equal 1, result.created
    event = AgentActivityEvent.find_by!(task: @task, run_id: "run-rt-2", seq: 1)
    assert_equal "tool_call", event.event_type
    assert_equal "runtime_hook", event.source
    assert_equal "printf hello", event.payload.dig("input", "command")
    assert_equal "/app", event.payload.dig("input", "cwd")
  end

  test "skips codemap events from persistence" do
    result = RuntimeEventsIngestionService.call(
      task: @task,
      run_id: "run-rt-3",
      map_id: "task_#{@task.id}",
      events: [
        { type: "state_sync", seq: 10, data: { map: { width: 2, height: 2 } } }
      ]
    )

    assert_equal 0, result.created
    assert_equal 1, result.codemap_events
  end
end
