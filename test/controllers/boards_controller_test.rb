# frozen_string_literal: true

require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)

    # Ensure we have at least one done task with a self-referential association.
    # Boards#show eager-loads :parent_task and :followup_task, which results in a
    # self-join on tasks. Unqualified ORDER BY completed_at becomes ambiguous.
    @parent = Task.create!(
      name: "Parent done",
      user: @user,
      board: @board,
      status: :done,
      completed: true,
      completed_at: 1.hour.ago
    )

    Task.create!(
      name: "Child done",
      user: @user,
      board: @board,
      status: :done,
      completed: true,
      completed_at: Time.current,
      parent_task: @parent
    )
  end

  test "should get show when authenticated" do
    sign_in_as(@user)
    get board_path(@board)
    assert_response :success
  end

  test "column endpoint paginates per status" do
    sign_in_as(@user)

    30.times do |i|
      Task.create!(
        name: "Inbox #{i}",
        user: @user,
        board: @board,
        status: :inbox
      )
    end

    get column_board_path(@board, status: "inbox", page: 1),
      headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_equal "true", response.headers["X-Has-More"]
    assert_equal 25, response.body.scan(/id=\"task_\d+\"/).length

    total_inbox = Task.where(board: @board, status: :inbox).count
    expected_second_page = total_inbox - 25

    get column_board_path(@board, status: "inbox", page: 2),
      headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_equal "false", response.headers["X-Has-More"]
    assert_equal expected_second_page, response.body.scan(/id=\"task_\d+\"/).length
  end

  test "index redirects to first board" do
    sign_in_as(@user)
    get boards_path
    assert_redirected_to board_path(@board)
  end

  test "requires authentication" do
    get board_path(@board)
    assert_response :redirect
  end

  test "cannot access other user's board" do
    sign_in_as(@user)
    other_board = boards(:two)
    get board_path(other_board)
    assert_response :not_found
  end

  test "create board" do
    sign_in_as(@user)
    assert_difference "Board.count", 1 do
      post boards_path, params: { board: { name: "New Board", icon: "🚀", color: "red" } }
    end
    assert_redirected_to board_path(Board.last)
  end

  test "update board" do
    sign_in_as(@user)
    patch board_path(@board), params: { board: { name: "Renamed" } }
    assert_redirected_to board_path(@board)
    assert_equal "Renamed", @board.reload.name
  end

  test "cannot delete last board" do
    sign_in_as(@user)
    # Ensure only one board
    @user.boards.where.not(id: @board.id).destroy_all
    delete board_path(@board)
    assert_redirected_to board_path(@board)
    assert Board.exists?(@board.id)
  end

  test "can delete board when multiple exist" do
    sign_in_as(@user)
    extra = Board.create!(name: "Extra", user: @user, icon: "🔧", color: "blue")
    assert_difference "Board.count", -1 do
      delete board_path(extra)
    end
    assert_redirected_to boards_path
  end

  test "archived page renders" do
    sign_in_as(@user)
    Task.create!(name: "Archived", user: @user, board: @board, status: :archived)
    get archived_board_path(@board)
    assert_response :success
  end

  test "update_task_status changes status" do
    sign_in_as(@user)
    task = Task.create!(name: "Move me", user: @user, board: @board, status: :inbox)
    patch update_task_status_board_path(@board), params: {
      task_id: task.id, status: "in_progress"
    }
    assert_response :success
    assert_equal "in_progress", task.reload.status
  end

  test "column endpoint rejects invalid status" do
    sign_in_as(@user)
    get column_board_path(@board, status: "bogus"),
      headers: { "X-Requested-With" => "XMLHttpRequest" }
    assert_response :bad_request
  end

  test "column endpoint rejects archived status" do
    sign_in_as(@user)
    get column_board_path(@board, status: "archived"),
      headers: { "X-Requested-With" => "XMLHttpRequest" }
    assert_response :bad_request
  end

  test "show with tag filter" do
    sign_in_as(@user)
    Task.create!(name: "Tagged", user: @user, board: @board, status: :inbox, tags: ["bug"])
    get board_path(@board, tag: "bug")
    assert_response :success
  end

end
