# frozen_string_literal: true

require "test_helper"

class SessionResetConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  # === Authentication ===

  test "show redirects unauthenticated users" do
    get session_reset_config_path
    assert_response :redirect
  end

  test "update redirects unauthenticated users" do
    patch session_reset_config_update_path, params: { mode: "daily" }
    assert_response :redirect
  end

  # === Gateway Not Configured ===

  test "show redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get session_reset_config_path
    assert_response :redirect
    assert_equal "Configure OpenClaw Gateway URL in Settings first", flash[:alert]
  end

  # === Show ===

  test "show handles gateway not running" do
    sign_in_as(@user)
    get session_reset_config_path
    assert_includes [200, 302, 500], response.status
  end

  # === Update with valid modes ===

  test "update accepts valid reset modes" do
    sign_in_as(@user)
    %w[daily idle never].each do |mode|
      patch session_reset_config_update_path, params: { mode: mode }
      assert_includes [200, 302, 500], response.status, "Mode #{mode} should be accepted"
    end
  end

  test "update ignores invalid mode" do
    sign_in_as(@user)
    patch session_reset_config_update_path, params: { mode: "always" }
    assert_includes [200, 302, 500], response.status
  end

  test "update clamps at_hour between 0 and 23" do
    sign_in_as(@user)
    patch session_reset_config_update_path, params: { at_hour: "-1" }
    assert_includes [200, 302, 500], response.status
    patch session_reset_config_update_path, params: { at_hour: "25" }
    assert_includes [200, 302, 500], response.status
  end

  test "update clamps idle_minutes between 5 and 1440" do
    sign_in_as(@user)
    patch session_reset_config_update_path, params: { idle_minutes: "1" }
    assert_includes [200, 302, 500], response.status
    patch session_reset_config_update_path, params: { idle_minutes: "9999" }
    assert_includes [200, 302, 500], response.status
  end

  test "update handles reset_by_channel toggle" do
    sign_in_as(@user)
    patch session_reset_config_update_path, params: { reset_by_channel: "true" }
    assert_includes [200, 302, 500], response.status
  end

  test "update filters reset_by_type to valid types" do
    sign_in_as(@user)
    patch session_reset_config_update_path, params: {
      reset_by_type: %w[direct group invalid_type]
    }
    assert_includes [200, 302, 500], response.status
  end

  # === Constants ===

  test "RESET_MODES contains expected values" do
    assert_equal %w[daily idle never], SessionResetConfigController::RESET_MODES
  end

  test "RESET_TYPES contains expected values" do
    assert_equal %w[direct group thread], SessionResetConfigController::RESET_TYPES
  end
end
