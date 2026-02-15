# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class IdentityConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get identity_config_path
    assert_response :redirect
  end

  test "show renders identity and messages config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {
      "identity" => { "name" => "Otacon", "emoji" => "📟" },
      "messages" => { "prefix" => "", "ackReaction" => "👍" }
    })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get identity_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "show handles gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "unreachable" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get identity_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "update identity name and emoji" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch identity_config_path, params: { name: "NewBot", emoji: "🤖" }
      assert_response :redirect
      assert_redirected_to identity_config_path
    end
    mock_client.verify
  end

  test "update messages config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch identity_config_path, params: {
        prefix: "[Bot]",
        response_prefix: "→",
        ack_reaction: "✅",
        ack_reaction_scope: "direct"
      }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update reports gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "error" => "timeout" }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch identity_config_path, params: { name: "Test" }
      assert_response :redirect
      follow_redirect!
    end
    mock_client.verify
  end
end
