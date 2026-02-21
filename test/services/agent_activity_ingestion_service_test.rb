# frozen_string_literal: true

require "test_helper"

class AgentActivityIngestionServiceTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  test "ingests valid events and normalizes defaults" do
    result = AgentActivityIngestionService.call(task: @task, events: [
      {
        run_id: "run-1",
        seq: 1,
        message: "hello",
        event_type: "unknown",
        payload: "not-a-hash"
      }
    ])

    assert_equal 1, result.created
    assert_equal 0, result.duplicates
    assert_empty result.errors

    event = AgentActivityEvent.find_by!(task_id: @task.id, run_id: "run-1", seq: 1)
    assert_equal "message", event.event_type
    assert_equal "info", event.level
    assert_equal "orchestrator", event.source
    assert_equal({}, event.payload)
  end

  test "counts duplicate rows and remains idempotent" do
    AgentActivityIngestionService.call(task: @task, events: [
      { run_id: "run-dup", seq: 1, event_type: "message", message: "a" }
    ])

    result = AgentActivityIngestionService.call(task: @task, events: [
      { run_id: "run-dup", seq: 1, event_type: "message", message: "a" }
    ])

    assert_equal 0, result.created
    assert_equal 1, result.duplicates
    assert_empty result.errors
  end

  test "for_task scope supports task object and id" do
    own = AgentActivityEvent.create!(task: @task, run_id: "scope-a", seq: 1, event_type: "message", level: "info", source: "test", message: "a")
    other_task = Task.create!(name: "Other", board: @task.board, user: @task.user)
    AgentActivityEvent.create!(task: other_task, run_id: "scope-b", seq: 1, event_type: "message", level: "info", source: "test", message: "b")

    assert_equal [own.id], AgentActivityEvent.for_task(@task.id).pluck(:id)
    assert_equal [own.id], AgentActivityEvent.for_task(@task).pluck(:id)
  end
end
