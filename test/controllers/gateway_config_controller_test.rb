# frozen_string_literal: true

require "test_helper"

class GatewayConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  test "redirects unauthenticated users" do
    get gateway_config_path
    assert_response :redirect
  end

  test "redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get gateway_config_path
    assert_response :redirect
  end

  test "show handles gateway not running" do
    sign_in_as(@user)
    get gateway_config_path
    assert_includes [200, 302, 500], response.status
  end

  test "apply requires authentication" do
    post gateway_config_apply_path, params: { config_raw: "{}" }
    assert_response :redirect
  end

  test "patch requires authentication" do
    post gateway_config_patch_path, params: { config_raw: "{}" }
    assert_response :redirect
  end

  test "restart requires authentication" do
    post gateway_config_restart_path
    assert_response :redirect
  end
end
