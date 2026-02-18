# frozen_string_literal: true

require "test_helper"

class Boards::RoadmapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
  end

  test "requires authentication for generate" do
    post generate_tasks_board_roadmap_path(@board)
    assert_response :redirect
  end

  test "cannot generate roadmap tasks for another user board" do
    sign_in_as(@user)
    other_board = boards(:two)

    assert_no_difference "Task.count" do
      post generate_tasks_board_roadmap_path(other_board)
    end

    assert_response :not_found
  end

  test "generate creates tasks and does not duplicate on rerun" do
    sign_in_as(@user)
    roadmap = BoardRoadmap.create!(
      board: @board,
      body: "- [ ] Alpha item\n- [ ] Beta item"
    )

    assert_difference "Task.count", 2 do
      post generate_tasks_board_roadmap_path(@board)
    end
    assert_redirected_to board_path(@board)

    assert_no_difference "Task.count" do
      post generate_tasks_board_roadmap_path(@board)
    end

    assert_equal 2, roadmap.reload.task_links.count
  end
end
