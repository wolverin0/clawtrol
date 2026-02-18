# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # --- RecordNotFound rescue ---

  test "accessing non-existent board returns 404 HTML" do
    sign_in_as(@user)
    get board_path(id: 999999)
    assert_response :not_found
  end

  test "accessing non-existent board via JSON returns 404 JSON" do
    sign_in_as(@user)
    get board_path(id: 999999, format: :json)
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Not found", json["error"]
  end

  test "accessing non-existent task returns 404" do
    sign_in_as(@user)
    board = boards(:one)
    get board_task_path(board, id: 999999)
    assert_response :not_found
  end

  # --- Security headers ---

  test "security headers are set on all responses" do
    sign_in_as(@user)
    get dashboard_path
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_includes response.headers["Permissions-Policy"], "camera=()"
    assert_equal "none", response.headers["X-Permitted-Cross-Domain-Policies"]
  end

  # --- Authentication redirect ---

  test "unauthenticated access to protected page redirects to login" do
    get dashboard_path
    assert_response :redirect
    assert_redirected_to new_session_path
  end
end
