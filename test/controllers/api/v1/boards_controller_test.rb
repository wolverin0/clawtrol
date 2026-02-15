# frozen_string_literal: true

require "test_helper"

class Api::V1::BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_token = api_tokens(:one)
    @board = boards(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
  end

  # --- Authentication ---

  test "returns unauthorized without token" do
    get api_v1_boards_url
    assert_response :unauthorized
  end

  # --- Index ---

  test "index returns boards for current user" do
    get api_v1_boards_url, headers: @auth_header
    assert_response :success

    boards = response.parsed_body
    assert_kind_of Array, boards
    assert boards.any? { |b| b["id"] == @board.id }
  end

  test "index includes tasks_count" do
    get api_v1_boards_url, headers: @auth_header
    assert_response :success

    boards = response.parsed_body
    board_data = boards.find { |b| b["id"] == @board.id }
    assert_not_nil board_data
    assert board_data.key?("tasks_count")
  end

  # --- Show ---

  test "show returns board details" do
    get api_v1_board_url(@board), headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert_equal @board.id, data["id"]
    assert_equal @board.name, data["name"]
  end

  test "show returns 404 for another users board" do
    other_user = users(:two)
    other_board = other_user.boards.first || other_user.boards.create!(name: "Other", position: 1)

    get api_v1_board_url(other_board), headers: @auth_header
    assert_response :not_found
  end

  test "show includes tasks when requested" do
    @board.tasks.create!(name: "Test task", user: @user)

    get api_v1_board_url(@board, include_tasks: "true"), headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert data.key?("tasks")
    assert_kind_of Array, data["tasks"]
  end

  # --- Create ---

  test "create board with valid params" do
    assert_difference("Board.count") do
      post api_v1_boards_url,
        params: { name: "New Board", icon: "🚀", color: "blue" },
        headers: @auth_header
    end

    assert_response :created
    data = response.parsed_body
    assert_equal "New Board", data["name"]
    assert_equal "🚀", data["icon"]
    assert_equal "blue", data["color"]
  end

  test "create board rejects blank name" do
    assert_no_difference("Board.count") do
      post api_v1_boards_url,
        params: { name: "", color: "gray" },
        headers: @auth_header
    end

    assert_response :unprocessable_entity
  end

  # --- Update ---

  test "update board name" do
    patch api_v1_board_url(@board),
      params: { name: "Updated Name" },
      headers: @auth_header

    assert_response :success
    assert_equal "Updated Name", @board.reload.name
  end

  test "update board auto_claim settings" do
    patch api_v1_board_url(@board),
      params: { auto_claim_enabled: true, auto_claim_prefix: "[BUG]" },
      headers: @auth_header

    assert_response :success
    @board.reload
    assert @board.auto_claim_enabled
    assert_equal "[BUG]", @board.auto_claim_prefix
  end

  # --- Destroy ---

  test "destroy board" do
    # Ensure user has at least 2 boards
    extra = @user.boards.create!(name: "Extra Board")

    assert_difference("Board.count", -1) do
      delete api_v1_board_url(extra), headers: @auth_header
    end

    assert_response :no_content
  end

  test "destroy rejects deleting last board" do
    # Remove all boards except one
    @user.boards.where.not(id: @board.id).destroy_all

    assert_no_difference("Board.count") do
      delete api_v1_board_url(@board), headers: @auth_header
    end

    assert_response :unprocessable_entity
    data = response.parsed_body
    assert_includes data["error"], "Cannot delete your only board"
  end

  # --- Status (polling endpoint) ---

  test "status returns fingerprint" do
    get status_api_v1_board_url(@board), headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert data.key?("fingerprint")
    assert data.key?("task_count")
  end
end
