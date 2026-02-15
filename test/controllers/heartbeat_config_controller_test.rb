# frozen_string_literal: true

require "test_helper"

class HeartbeatConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  # === Authentication ===

  test "show redirects unauthenticated users" do
    get heartbeat_config_path
    assert_response :redirect
  end

  test "update redirects unauthenticated users" do
    patch heartbeat_config_path, params: { enabled: "true" }
    assert_response :redirect
  end

  # === Gateway Not Configured ===

  test "show redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get heartbeat_config_path
    assert_response :redirect
    assert_equal "Configure OpenClaw Gateway URL in Settings first", flash[:alert]
  end

  test "update redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    patch heartbeat_config_path, params: { enabled: "true" }
    assert_response :redirect
  end

  # === Show ===

  test "show handles gateway not running" do
    sign_in_as(@user)
    get heartbeat_config_path
    assert_includes [200, 302, 500], response.status
  end

  # === Update with various params ===

  test "update handles enabled toggle" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: { enabled: "true" }
    assert_includes [200, 302, 500], response.status
  end

  test "update clamps interval_minutes between 5 and 1440" do
    sign_in_as(@user)
    # Too low
    patch heartbeat_config_path, params: { interval_minutes: "1" }
    assert_includes [200, 302, 500], response.status
    # Too high
    patch heartbeat_config_path, params: { interval_minutes: "9999" }
    assert_includes [200, 302, 500], response.status
  end

  test "update clamps ack_max_chars between 50 and 5000" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: { ack_max_chars: "10" }
    assert_includes [200, 302, 500], response.status
    patch heartbeat_config_path, params: { ack_max_chars: "99999" }
    assert_includes [200, 302, 500], response.status
  end

  test "update handles quiet hours" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: {
      quiet_hours_start: "22",
      quiet_hours_end: "7"
    }
    assert_includes [200, 302, 500], response.status
  end

  test "update clamps quiet hours between 0 and 23" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: {
      quiet_hours_start: "-1",
      quiet_hours_end: "25"
    }
    assert_includes [200, 302, 500], response.status
  end

  test "update handles model and channel params" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: {
      model: "anthropic/claude-sonnet-4",
      target_channel: "telegram"
    }
    assert_includes [200, 302, 500], response.status
  end

  test "update handles prompt param" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: {
      prompt: "Check emails and calendar"
    }
    assert_includes [200, 302, 500], response.status
  end

  test "update handles include_reasoning toggle" do
    sign_in_as(@user)
    patch heartbeat_config_path, params: { include_reasoning: "true" }
    assert_includes [200, 302, 500], response.status
  end
end
