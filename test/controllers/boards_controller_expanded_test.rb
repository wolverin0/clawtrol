# frozen_string_literal: true

require "test_helper"

class BoardsControllerExpandedTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    sign_in_as(@user)
  end

  test "index redirects to first board" do
    get boards_path
    assert_response :redirect
    assert_redirected_to board_path(@board)
  end

  test "show requires authentication" do
    delete session_path
    get board_path(@board)
    assert_response :redirect
  end

  test "create board" do
    assert_difference "@user.boards.count", 1 do
      post boards_path, params: { board: { name: "New Board", icon: "🚀", color: "blue" } }
    end
    assert_response :redirect
  end

  test "update board" do
    patch board_path(@board), params: { board: { name: "Renamed" } }
    assert_response :redirect
    assert_equal "Renamed", @board.reload.name
  end

  test "destroy board when multiple exist" do
    new_board = @user.boards.create!(name: "Second", icon: "📝", color: "blue")
    assert_difference "@user.boards.count", -1 do
      delete board_path(new_board)
    end
    assert_response :redirect
  end

  test "cannot destroy last board" do
    assert_no_difference "@user.boards.count" do
      delete board_path(@board)
    end
    assert_response :redirect
    assert_match(/Cannot delete/, flash[:alert])
  end

  test "update_task_status via JSON" do
    task = tasks(:one)
    patch update_task_status_board_path(@board), params: {
      task_id: task.id, status: "in_progress"
    }, xhr: true
    assert_response :success
    assert_equal "in_progress", task.reload.status
  end

  test "archived page renders" do
    get archived_board_path(@board)
    assert_response :success
  end

  test "column endpoint for specific status" do
    get column_board_path(@board, status: "inbox", page: 1),
      headers: { "X-Requested-With" => "XMLHttpRequest" }
    assert_response :success
  end

  test "cannot access other users board" do
    other_board = boards(:two)
    get board_path(other_board)
    # Should redirect or raise — the controller uses find which scopes to current_user
    assert_response :not_found
  rescue ActiveRecord::RecordNotFound
    # Also acceptable
    assert true
  end
end
