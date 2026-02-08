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

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
