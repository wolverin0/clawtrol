# frozen_string_literal: true

require "test_helper"

class BulkTaskServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task1 = Task.create!(name: "Bulk Test 1", board: @board, user: @user, status: :inbox)
    @task2 = Task.create!(name: "Bulk Test 2", board: @board, user: @user, status: :inbox)
    @task3 = Task.create!(name: "Bulk Test 3", board: @board, user: @user, status: :up_next)
  end

  # --- move_status ---

  test "move_status changes tasks to target status" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id, @task2.id],
      action_type: "move_status",
      value: "up_next"
    ).call

    assert result.success
    assert_equal 2, result.affected_count
    assert_includes result.affected_statuses, "up_next"

    assert_equal "up_next", @task1.reload.status
    assert_equal "up_next", @task2.reload.status
  end

  test "move_status rejects invalid status" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id],
      action_type: "move_status",
      value: "nonexistent"
    ).call

    assert_not result.success
    assert_match(/Invalid status/, result.error)
  end

  # --- change_model ---

  test "change_model updates model on tasks" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id, @task2.id],
      action_type: "change_model",
      value: "opus"
    ).call

    assert result.success
    assert_equal 2, result.affected_count
    assert_equal "opus", @task1.reload.model
    assert_equal "opus", @task2.reload.model
  end

  test "change_model clears model when value is blank" do
    @task1.update!(model: "opus")

    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id],
      action_type: "change_model",
      value: ""
    ).call

    assert result.success
    assert_nil @task1.reload.model
  end

  # --- archive ---

  test "archive moves tasks to archived status" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id, @task3.id],
      action_type: "archive",
      value: nil
    ).call

    assert result.success
    assert_equal 2, result.affected_count
    assert_equal "archived", @task1.reload.status
    assert_equal "archived", @task3.reload.status
    assert_includes result.affected_statuses, "archived"
  end

  # --- delete ---

  test "delete destroys tasks" do
    ids = [@task1.id, @task2.id]

    result = BulkTaskService.new(
      board: @board,
      task_ids: ids,
      action_type: "delete",
      value: nil
    ).call

    assert result.success
    assert_equal 2, result.affected_count
    assert_not Task.exists?(ids.first)
    assert_not Task.exists?(ids.second)
  end

  # --- Error cases ---

  test "rejects empty task_ids" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [],
      action_type: "move_status",
      value: "done"
    ).call

    assert_not result.success
    assert_match(/No tasks selected/, result.error)
  end

  test "rejects invalid action_type" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id],
      action_type: "explode",
      value: nil
    ).call

    assert_not result.success
    assert_match(/Invalid action/, result.error)
  end

  test "only affects tasks within the board" do
    other_board = Board.create!(name: "Other Board", user: @user)
    other_task = Task.create!(name: "Other Board Task", board: other_board, user: @user, status: :inbox)

    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id, other_task.id],
      action_type: "move_status",
      value: "done"
    ).call

    assert result.success
    # Only the task from @board should be affected
    assert_equal "done", @task1.reload.status
    assert_equal "inbox", other_task.reload.status
  end

  test "affected_statuses includes both original and target statuses" do
    result = BulkTaskService.new(
      board: @board,
      task_ids: [@task1.id, @task3.id],
      action_type: "move_status",
      value: "done"
    ).call

    assert result.success
    # Original statuses were inbox and up_next, target is done
    assert_includes result.affected_statuses, "inbox"
    assert_includes result.affected_statuses, "up_next"
    assert_includes result.affected_statuses, "done"
  end
end
