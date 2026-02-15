# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SendPolicyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get send_policy_path
    assert_response :redirect
  end

  test "show redirects when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get send_policy_path
    assert_response :redirect
  end

  test "show renders send policy config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {
      "config" => {
        "session" => { "sendPolicy" => { "rules" => [] } },
        "accessGroups" => {}
      }
    })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get send_policy_path
      assert_response :success
    end
    mock_client.verify
  end

  test "show handles gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "timeout" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get send_policy_path
      assert_response :success
    end
    mock_client.verify
  end
end
