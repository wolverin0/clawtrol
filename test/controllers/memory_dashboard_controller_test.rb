# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class MemoryDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get memory_dashboard_path
    assert_response :redirect
  end

  test "redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)

    get memory_dashboard_path
    assert_redirected_to settings_path
  end

  test "shows memory dashboard with plugin data" do
    sign_in_as(@user)

    mock_health = {
      "loadedPlugins" => [
        { "name" => "memory-core", "enabled" => true, "version" => "1.2.0", "status" => "active" },
        { "name" => "other-plugin", "enabled" => true }
      ],
      "memory" => {
        "totalEntries" => 150,
        "lastIndexed" => "2026-02-15T08:00:00Z",
        "backend" => "sqlite"
      }
    }

    mock_config = {
      "memory" => {
        "autoRecall" => true,
        "autoCapture" => false,
        "backend" => "sqlite"
      }
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:health, mock_health)
    mock_client.expect(:config_get, mock_config)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get memory_dashboard_path
    end

    assert_response :success
    mock_client.verify
  end

  test "handles gateway error on show" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:health, { "error" => "unreachable" })
    mock_client.expect(:config_get, { "error" => "unreachable" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get memory_dashboard_path
    end

    assert_response :success
    mock_client.verify
  end

  test "search with blank query returns no results" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:health, { "loadedPlugins" => [] })
    mock_client.expect(:config_get, {})

    OpenclawGatewayClient.stub(:new, mock_client) do
      post memory_search_path, params: { query: "" }
    end

    assert_response :success
    mock_client.verify
  end

  test "search with overly long query shows alert" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:health, { "loadedPlugins" => [] })
    mock_client.expect(:config_get, {})

    OpenclawGatewayClient.stub(:new, mock_client) do
      post memory_search_path, params: { query: "x" * 501 }
    end

    assert_response :success
    mock_client.verify
  end
end
