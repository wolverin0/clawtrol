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

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
