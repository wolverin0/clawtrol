# frozen_string_literal: true

require "test_helper"

class QuickAddControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
  end

  # --- Authentication ---

  test "new requires authentication" do
    get quick_add_path
    assert_response :redirect
  end

  test "create requires authentication" do
    post quick_add_path, params: { name: "Test" }
    assert_response :redirect
  end

  # --- GET /quick_add ---

  test "new renders form when authenticated" do
    sign_in_as(@user)
    get quick_add_path
    assert_response :success
  end

  # --- POST /quick_add (validation) ---

  test "create requires name" do
    sign_in_as(@user)
    assert_no_difference "Task.count" do
      post quick_add_path, params: { name: "" }
    end
    assert_redirected_to quick_add_path
    assert_equal "Title is required", flash[:alert]
  end

  test "create requires whitespace-only name is treated as blank" do
    sign_in_as(@user)
    assert_no_difference "Task.count" do
      post quick_add_path, params: { name: "   " }
    end
    assert_redirected_to quick_add_path
  end

  # --- POST /quick_add (success) ---

  test "create saves task with valid params" do
    sign_in_as(@user)
    assert_difference "Task.count", 1 do
      post quick_add_path, params: {
        name: "Fix the login page",
        description: "CSS is broken on mobile",
        board_id: @board.id
      }
    end
    assert_redirected_to quick_add_path
    assert_match(/Task #\d+ created/, flash[:notice])

    task = Task.order(:created_at).last
    assert_equal "Fix the login page", task.name
    assert_equal "CSS is broken on mobile", task.description
    assert_equal "inbox", task.status
    assert_equal @user.id, task.user_id
    assert_equal @board.id, task.board_id
  end

  test "create falls back to first board when board_id is invalid" do
    sign_in_as(@user)
    assert_difference "Task.count", 1 do
      post quick_add_path, params: { name: "Orphan task", board_id: 999999 }
    end
    assert_redirected_to quick_add_path
  end

  test "create auto-tags based on name content" do
    sign_in_as(@user)
    post quick_add_path, params: { name: "Fix XSS vulnerability in login" }
    task = Task.order(:created_at).last
    assert_includes task.tags, "security"
  end

  test "create merges user-provided tags with auto tags" do
    sign_in_as(@user)
    post quick_add_path, params: {
      name: "Add dark mode",
      tags: ["custom-tag", "frontend"]
    }
    task = Task.order(:created_at).last
    assert_includes task.tags, "custom-tag"
    assert_includes task.tags, "frontend"
  end

  test "create truncates excessively long name" do
    sign_in_as(@user)
    long_name = "A" * 1000
    post quick_add_path, params: { name: long_name }
    task = Task.order(:created_at).last
    assert task.name.length <= 500
  end

  test "create truncates excessively long description" do
    sign_in_as(@user)
    long_desc = "B" * 20_000
    post quick_add_path, params: { name: "Test", description: long_desc }
    task = Task.order(:created_at).last
    assert task.description.length <= 10_000
  end

  test "create limits tags to 10" do
    sign_in_as(@user)
    many_tags = (1..20).map { |i| "tag-#{i}" }
    post quick_add_path, params: { name: "Tagged task", tags: many_tags }
    task = Task.order(:created_at).last
    assert task.tags.length <= 10
  end

  # --- Scoping ---

  test "create only uses boards belonging to current user" do
    other_user = users(:two)
    other_board = boards(:two)

    sign_in_as(@user)
    post quick_add_path, params: { name: "Scoped task", board_id: other_board.id }
    task = Task.order(:created_at).last
    # Should fall back to user's own board, not use other user's board
    assert_equal @user.id, task.user_id
    assert_includes @user.boards.pluck(:id), task.board_id
  end
end
