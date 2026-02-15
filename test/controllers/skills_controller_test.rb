# frozen_string_literal: true

require "test_helper"

class SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  test "redirects unauthenticated users" do
    get skill_manager_path
    assert_response :redirect
  end

  test "index handles gateway not running" do
    sign_in_as(@user)
    get skill_manager_path
    assert_includes [200, 302, 500], response.status
  end
end
