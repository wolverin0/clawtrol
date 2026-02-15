# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ConfigHubControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get config_hub_path
    assert_response :redirect
  end

  test "show renders config hub with sections" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:health, { "status" => "ok" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get config_hub_path
      assert_response :success
      # Check for key section titles
      assert_match(/Channels/i, response.body)
      assert_match(/Agent/i, response.body)
      assert_match(/System/i, response.body)
    end
    mock_client.verify
  end

  test "show renders even when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get config_hub_path
    assert_response :success
  end

  test "show handles gateway health error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:health, { "error" => "unreachable" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get config_hub_path
      assert_response :success
    end
    mock_client.verify
  end
end
