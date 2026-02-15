# frozen_string_literal: true

require "test_helper"

# Auth guard tests for gateway config controllers that lack test coverage.
# These all require authentication and gateway configuration.
# We test: unauthenticated redirect, authenticated with gateway → success or expected error.
class GatewayConfigControllersTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # === Canvas Controller ===
  test "canvas requires auth" do
    get canvas_path rescue nil
    assert_response :redirect
  end

  # === Heartbeat Config ===
  test "heartbeat config requires auth" do
    get heartbeat_config_path
    assert_response :redirect
  end

  test "heartbeat config loads for authenticated user" do
    sign_in_as(@user)
    get heartbeat_config_path
    # May redirect if gateway not configured, but should not 500
    assert_includes [200, 302], response.status
  end

  # === Identity Config ===
  test "identity config requires auth" do
    get identity_config_path
    assert_response :redirect
  end

  test "identity config loads for authenticated user" do
    sign_in_as(@user)
    get identity_config_path
    assert_includes [200, 302], response.status
  end

  # === Session Maintenance ===
  test "session maintenance requires auth" do
    get session_maintenance_path
    assert_response :redirect
  end

  test "session maintenance loads for authenticated user" do
    sign_in_as(@user)
    get session_maintenance_path
    assert_includes [200, 302], response.status
  end

  # === Compaction Config ===
  test "compaction config requires auth" do
    get compaction_config_path
    assert_response :redirect
  end

  test "compaction config loads for authenticated user" do
    sign_in_as(@user)
    get compaction_config_path
    assert_includes [200, 302], response.status
  end

  # === Media Config ===
  test "media config requires auth" do
    get media_config_path
    assert_response :redirect
  end

  test "media config loads for authenticated user" do
    sign_in_as(@user)
    get media_config_path
    assert_includes [200, 302], response.status
  end

  # === Session Reset Config ===
  test "session reset config requires auth" do
    get session_reset_config_path
    assert_response :redirect
  end

  test "session reset config loads for authenticated user" do
    sign_in_as(@user)
    get session_reset_config_path
    assert_includes [200, 302], response.status
  end

  # === DM Policy ===
  test "dm policy requires auth" do
    get dm_policy_path
    assert_response :redirect
  end

  test "dm policy loads for authenticated user" do
    sign_in_as(@user)
    get dm_policy_path
    assert_includes [200, 302], response.status
  end

  # === Typing Config ===
  test "typing config requires auth" do
    get typing_config_path
    assert_response :redirect
  end

  test "typing config loads for authenticated user" do
    sign_in_as(@user)
    get typing_config_path
    assert_includes [200, 302], response.status
  end

  # === Sandbox Config ===
  test "sandbox config requires auth" do
    get sandbox_config_path
    assert_response :redirect
  end

  test "sandbox config loads for authenticated user" do
    sign_in_as(@user)
    get sandbox_config_path
    assert_includes [200, 302], response.status
  end

  # === Send Policy ===
  test "send policy requires auth" do
    get send_policy_path
    assert_response :redirect
  end

  test "send policy loads for authenticated user" do
    sign_in_as(@user)
    get send_policy_path
    assert_includes [200, 302], response.status
  end

  # === Message Queue Config ===
  test "message queue config requires auth" do
    get message_queue_config_path
    assert_response :redirect
  end

  test "message queue config loads for authenticated user" do
    sign_in_as(@user)
    get message_queue_config_path
    assert_includes [200, 302], response.status
  end
end
