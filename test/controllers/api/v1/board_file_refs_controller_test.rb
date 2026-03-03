# frozen_string_literal: true

require "test_helper"

class Api::V1::BoardFileRefsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @board = boards(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
  end

  test "index returns refs for board" do
    @board.file_refs.create!(path: "clawdeck/README.md", category: "docs", label: "Readme")

    get api_v1_board_file_refs_url(@board), headers: @auth_header
    assert_response :success
    assert_equal 1, response.parsed_body.size
  end

  test "create rejects unsafe path" do
    assert_no_difference("BoardFileRef.count") do
      post api_v1_board_file_refs_url(@board),
        params: { path: "../.env", category: "general" },
        headers: @auth_header
    end

    assert_response :unprocessable_entity
  end
end
