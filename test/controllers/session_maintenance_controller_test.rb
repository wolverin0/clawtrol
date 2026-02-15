# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SessionMaintenanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get session_maintenance_path
    assert_response :redirect
  end

  test "redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)

    get session_maintenance_path
    assert_redirected_to settings_path
  end

  test "shows session maintenance page" do
    sign_in_as(@user)

    mock_config = {
      "session" => {
        "store" => {
          "pruneAfter" => 168,
          "maxEntries" => 500,
          "rotateBytes" => 0,
          "autoCleanup" => true
        }
      }
    }

    mock_sessions = {
      "sessions" => [
        { "key" => "sess1", "active" => true, "createdAt" => "2026-02-15", "totalTokens" => 1000 },
        { "key" => "sess2", "active" => false, "createdAt" => "2026-02-14", "totalTokens" => 500 }
      ]
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)
    mock_client.expect(:sessions_list, mock_sessions)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get session_maintenance_path
    end

    assert_response :success
    mock_client.verify
  end

  test "handles gateway error gracefully" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "Connection refused" })
    mock_client.expect(:sessions_list, { "sessions" => [] })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get session_maintenance_path
    end

    assert_response :success
    mock_client.verify
  end

  test "update patches config and redirects" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch session_maintenance_path, params: {
        prune_after_hours: "72",
        max_entries: "2000",
        auto_cleanup: "true"
      }
    end

    assert_redirected_to session_maintenance_path
    assert_match(/updated/, flash[:notice])
    mock_client.verify
  end

  test "update clamps prune_after_hours to valid range" do
    sign_in_as(@user)

    # The build_maintenance_patch method clamps values — verify via patch call
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }) do |raw:, reason:|
      parsed = JSON.parse(raw)
      prune = parsed.dig("session", "store", "pruneAfter")
      # 0 should be clamped to 1
      prune >= 1 && prune <= 8760
    end

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch session_maintenance_path, params: { prune_after_hours: "0" }
    end

    assert_redirected_to session_maintenance_path
    mock_client.verify
  end

  test "update handles gateway error" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "error" => "Gateway unreachable" }, raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch session_maintenance_path, params: { max_entries: "500" }
    end

    assert_redirected_to session_maintenance_path
    assert_match(/Failed/, flash[:alert])
    mock_client.verify
  end
end
