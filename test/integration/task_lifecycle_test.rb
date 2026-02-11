require "test_helper"

class TaskLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    sign_in_as(@user)
  end

  test "full task lifecycle: create, move through statuses, complete" do
    # Create task
    post board_tasks_path(@board), params: {
      task: { name: "Lifecycle task", priority: "high" }
    }
    task = Task.find_by(name: "Lifecycle task")
    assert task, "Task should be created"
    assert_equal "inbox", task.status

    # Move to up_next
    patch move_board_task_path(@board, task), params: { status: "up_next" }
    assert_equal "up_next", task.reload.status

    # Move to in_progress
    patch move_board_task_path(@board, task), params: { status: "in_progress" }
    assert_equal "in_progress", task.reload.status

    # Move to in_review
    patch move_board_task_path(@board, task), params: { status: "in_review" }
    assert_equal "in_review", task.reload.status

    # Move to done
    patch move_board_task_path(@board, task), params: { status: "done" }
    assert_equal "done", task.reload.status
  end

  test "agent workflow: assign, hooks fire, task goes to in_review" do
    task = Task.create!(name: "Agent task", user: @user, board: @board, status: :up_next)

    # Assign to agent
    patch assign_board_task_path(@board, task)
    assert task.reload.assigned_to_agent

    # Simulate task_outcome hook
    token = Rails.application.config.hooks_token
    run_id = SecureRandom.uuid
    post "/api/v1/hooks/task_outcome",
         params: {
           task_id: task.id, version: "1", run_id: run_id,
           summary: "Tests written", needs_follow_up: false, achieved: ["tests"]
         },
         headers: { "X-Hook-Token" => token },
         as: :json
    assert_response :success
    assert_equal "in_review", task.reload.status

    # Simulate agent_complete hook
    post "/api/v1/hooks/agent_complete",
         params: { task_id: task.id, findings: "All tests pass" },
         headers: { "X-Hook-Token" => token },
         as: :json
    assert_response :success
    assert_match(/All tests pass/, task.reload.description)
  end

  test "search finds task by name" do
    Task.create!(name: "Unique searchable term xyz123", user: @user, board: @board, status: :inbox)
    get search_path(q: "xyz123")
    assert_response :success
    assert_match(/xyz123/, response.body)
  end

  test "unauthenticated user cannot access any protected resource" do
    delete session_path

    [dashboard_path, boards_path, search_path, nightbeat_path].each do |path|
      get path
      assert_response :redirect, "#{path} should redirect unauthenticated user"
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
