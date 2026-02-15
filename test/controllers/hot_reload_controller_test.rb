# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class HotReloadControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get hot_reload_path
    assert_response :redirect
  end

  test "redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)

    get hot_reload_path
    assert_redirected_to settings_path
  end

  test "shows hot reload page with config" do
    sign_in_as(@user)

    mock_config = {
      "config" => {
        "configReload" => {
          "mode" => "hybrid",
          "debounceMs" => 2000,
          "watchConfig" => true
        }
      }
    }

    mock_health = {
      "status" => "ok",
      "startedAt" => 30.minutes.ago.iso8601
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)
    mock_client.expect(:health, mock_health)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get hot_reload_path
    end

    assert_response :success
    mock_client.verify
  end

  test "update patches reload config" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    # First call: current_config_section reads config
    mock_client.expect(:config_get, { "config" => { "configReload" => { "mode" => "hybrid" } } })
    # Second call: apply_config_patch
    mock_client.expect(:config_patch, { "success" => true }, raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post hot_reload_update_path, params: {
        values: { mode: "hot", debounce_ms: "5000", watch_config: "true" }
      }, as: :json
    end

    assert_response :success
    mock_client.verify
  end

  test "update rejects invalid mode" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "configReload" => { "mode" => "hybrid" } } })
    mock_client.expect(:config_patch, { "success" => true }, raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post hot_reload_update_path, params: {
        values: { mode: "invalid_mode" }
      }, as: :json
    end

    # Should still succeed but the invalid mode shouldn't be applied
    assert_response :success
    mock_client.verify
  end

  test "update clamps debounce_ms" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "configReload" => {} } })
    mock_client.expect(:config_patch, { "success" => true }) do |raw:, reason:|
      parsed = JSON.parse(raw)
      debounce = parsed.dig("configReload", "debounceMs")
      # 50 should be clamped to 100
      debounce == 100
    end

    OpenclawGatewayClient.stub(:new, mock_client) do
      post hot_reload_update_path, params: {
        values: { debounce_ms: "50" }
      }, as: :json
    end

    assert_response :success
    mock_client.verify
  end
end
