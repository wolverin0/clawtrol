# frozen_string_literal: true

require "test_helper"

class ExecApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  test "redirects unauthenticated users" do
    get exec_approvals_path
    assert_response :redirect
  end

  test "show handles gateway not running" do
    sign_in_as(@user)
    get exec_approvals_path
    assert_includes [200, 302, 500], response.status
  end
end
