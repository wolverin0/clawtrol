require "test_helper"

class Boards::TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "requires authentication for show" do
    sign_out
    get board_task_path(@board, @task)
    assert_response :redirect
  end

  # --- CRUD ---

  test "show renders task" do
    get board_task_path(@board, @task)
    assert_response :success
  end

  test "show renders without layout for turbo frame" do
    get board_task_path(@board, @task), headers: { "Turbo-Frame" => "task_detail" }
    assert_response :success
  end

  test "new renders form" do
    get new_board_task_path(@board)
    assert_response :success
  end

  test "create task" do
    assert_difference "Task.count", 1 do
      post board_tasks_path(@board), params: {
        task: { name: "New task", description: "Desc", priority: "high" }
      }
    end
    task = Task.last
    assert_equal "New task", task.name
    assert_equal "inbox", task.status
    assert_equal @user, task.user
  end

  test "create task with invalid params" do
    assert_no_difference "Task.count" do
      post board_tasks_path(@board), params: {
        task: { name: "" }
      }
    end
  end

  test "update task" do
    patch board_task_path(@board, @task), params: {
      task: { name: "Updated name" }
    }
    assert_redirected_to board_path(@board)
    assert_equal "Updated name", @task.reload.name
  end

  test "destroy task" do
    assert_difference "Task.count", -1 do
      delete board_task_path(@board, @task)
    end
    assert_redirected_to board_path(@board)
  end

  # --- Move between columns ---

  test "move task to different status" do
    patch move_board_task_path(@board, @task), params: { status: "in_progress" }
    assert_redirected_to board_path(@board)
    assert_equal "in_progress", @task.reload.status
  end

  test "move task with invalid status raises error" do
    assert_raises(ArgumentError) do
      patch move_board_task_path(@board, @task), params: { status: "nonexistent" }
    end
  end

  test "move task to another board" do
    other_board = Board.create!(name: "Other", user: @user, icon: "🔧", color: "blue")
    patch move_to_board_board_task_path(@board, @task), params: { target_board_id: other_board.id }
    assert_equal other_board.id, @task.reload.board_id
  end

  # --- Assign / Unassign ---

  test "assign task to agent" do
    patch assign_board_task_path(@board, @task)
    assert @task.reload.assigned_to_agent
  end

  test "unassign task from agent" do
    @task.update!(assigned_to_agent: true, assigned_at: Time.current)
    patch unassign_board_task_path(@board, @task)
    assert_not @task.reload.assigned_to_agent
  end

  # --- Scoping: user cannot access other user's tasks ---

  test "cannot access other user's board tasks" do
    other_board = boards(:two)
    other_task = tasks(:two)
    get board_task_path(other_board, other_task)
    assert_response :not_found
  end

  # --- Bulk update ---

  test "bulk move tasks" do
    t2 = Task.create!(name: "Bulk task", user: @user, board: @board, status: :inbox)
    post bulk_update_board_tasks_path(@board), params: {
      task_ids: [@task.id, t2.id], action_type: "move_status", value: "up_next"
    }
    assert_equal "up_next", @task.reload.status
    assert_equal "up_next", t2.reload.status
  end

  test "bulk delete tasks" do
    t2 = Task.create!(name: "Delete me", user: @user, board: @board, status: :inbox)
    assert_difference "Task.count", -2 do
      post bulk_update_board_tasks_path(@board), params: {
        task_ids: [@task.id, t2.id], action_type: "delete"
      }
    end
  end

  test "bulk update with unknown action" do
    post bulk_update_board_tasks_path(@board), params: {
      task_ids: [@task.id], action_type: "explode"
    }, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_entity
  end

  # --- View file (security) ---

  test "view_file rejects path traversal" do
    get view_file_board_task_path(@board, @task, path: "../../etc/passwd")
    assert_response :forbidden
  end

  test "view_file rejects absolute paths" do
    get view_file_board_task_path(@board, @task, path: "/etc/passwd")
    assert_response :forbidden
  end

  test "view_file rejects dotfile paths" do
    get view_file_board_task_path(@board, @task, path: ".ssh/id_rsa")
    assert_response :forbidden
  end

  test "view_file rejects null bytes" do
    get view_file_board_task_path(@board, @task, path: "file.txt\x00.rb")
    assert_response :forbidden
  end

  test "view_file requires path param" do
    get view_file_board_task_path(@board, @task, path: "")
    assert_response :bad_request
  end

  # --- Followup ---

  test "create followup task" do
    post create_followup_board_task_path(@board, @task), params: {
      followup_name: "Follow up task",
      followup_description: "Do more",
      destination: "inbox"
    }
    followup = Task.find_by(name: "Follow up task")
    assert followup
    assert_equal "done", @task.reload.status
  end

  # --- Handoff ---

  test "handoff with invalid model" do
    post handoff_board_task_path(@board, @task), params: { model: "invalid_model" }
    assert_redirected_to board_path(@board)
    follow_redirect!
    assert_match /Invalid model/, flash[:alert]
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def sign_out
    delete session_path
  end
end
