# frozen_string_literal: true

require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    sign_in_as(@user)
  end

  test "search requires authentication" do
    delete session_path
    get search_path(q: "test")
    assert_response :redirect
  end

  test "search with query returns results page" do
    get search_path(q: "Test Task One")
    assert_response :success
  end

  test "search with empty query returns page" do
    get search_path(q: "")
    assert_response :success
  end

  test "search scopes to current user only" do
    # Search for other user's task — should show "no results"
    get search_path(q: "Test Task Two")
    assert_response :success
    assert_match(/No results found/, response.body)
  end

end
