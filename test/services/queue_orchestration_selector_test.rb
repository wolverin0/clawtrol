# frozen_string_literal: true

require "test_helper"

class QueueOrchestrationSelectorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "selects max one task per board and keeps FIFO by task id" do
    user = users(:one)
    board_a = Board.create!(user: user, name: "Selector A", position: 0)
    board_b = Board.create!(user: user, name: "Selector B", position: 1)

    first_a = Task.create!(user: user, board: board_a, name: "A-1", status: :up_next, assigned_to_agent: true, blocked: false, model: "codex")
    Task.create!(user: user, board: board_a, name: "A-2", status: :up_next, assigned_to_agent: true, blocked: false, model: "codex")
    first_b = Task.create!(user: user, board: board_b, name: "B-1", status: :up_next, assigned_to_agent: true, blocked: false, model: "gemini3")

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      selector = QueueOrchestrationSelector.new(user, now: Time.current)
      plan = selector.plan(limit: 10)

      assert_equal 2, plan.tasks.length
      assert_equal [first_a.id, first_b.id].sort, plan.tasks.map(&:id).sort
      assert plan.skip_reasons["board_busy"].to_i >= 1
    end
  end

  test "skips models that reached inflight quota" do
    user = users(:one)
    board_a = Board.create!(user: user, name: "Quota A", position: 0)
    board_b = Board.create!(user: user, name: "Quota B", position: 1)
    board_c = Board.create!(user: user, name: "Quota C", position: 2)

    Task.create!(user: user, board: board_a, name: "working-1", status: :in_progress, assigned_to_agent: true, blocked: false, model: "codex")
    Task.create!(user: user, board: board_b, name: "working-2", status: :in_progress, assigned_to_agent: true, blocked: false, model: "codex")
    Task.create!(user: user, board: board_c, name: "queued-codex", status: :up_next, assigned_to_agent: true, blocked: false, model: "codex")

    travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
      selector = QueueOrchestrationSelector.new(user, now: Time.current)
      plan = selector.plan(limit: 10)

      assert_equal 0, plan.tasks.length
      assert plan.skip_reasons["model_quota_reached"].to_i >= 1
    end
  end

  test "metrics exposes queue and inflight snapshot" do
    user = users(:one)
    board = Board.create!(user: user, name: "Metrics Board", position: 0)

    Task.create!(user: user, board: board, name: "inprogress", status: :in_progress, assigned_to_agent: true, blocked: false, model: "gemini3")
    Task.create!(user: user, board: board, name: "queued", status: :up_next, assigned_to_agent: true, blocked: false, model: "glm")

    selector = QueueOrchestrationSelector.new(user, now: Time.current)
    metrics = selector.metrics

    assert metrics.key?(:queue_depth)
    assert metrics.key?(:active_in_progress)
    assert metrics.key?(:inflight_by_model)
    assert_equal 1, metrics[:active_in_progress]
    assert_equal 1, metrics[:queue_depth]
  end
end
