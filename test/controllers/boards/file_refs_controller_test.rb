# frozen_string_literal: true

require "test_helper"

class Boards::FileRefsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    sign_in_as(@user)
  end

  test "creates file reference with safe path" do
    assert_difference("BoardFileRef.count", 1) do
      post board_file_refs_path(@board), params: {
        board_file_ref: {
          path: "clawdeck/README.md",
          label: "Readme",
          category: "docs"
        }
      }
    end

    assert_redirected_to board_path(@board)
  end

  test "rejects create with traversal path" do
    assert_no_difference("BoardFileRef.count") do
      post board_file_refs_path(@board), params: {
        board_file_ref: {
          path: "../.env",
          label: "Nope",
          category: "general"
        }
      }
    end

    assert_redirected_to board_path(@board)
  end
end
