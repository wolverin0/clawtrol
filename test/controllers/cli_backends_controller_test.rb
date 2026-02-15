# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class CliBackendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get cli_backends_path
    assert_response :redirect
  end

  test "redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)

    get cli_backends_path
    assert_redirected_to settings_path
  end

  test "shows CLI backends page" do
    sign_in_as(@user)

    mock_config = {
      "cliBackends" => {
        "claude-cli" => {
          "command" => "claude",
          "args" => ["--mode", "full"],
          "modelArg" => "--model",
          "enabled" => true,
          "fallbackPriority" => 1,
          "description" => "Claude CLI backend"
        },
        "custom-cli" => {
          "command" => "my-cli",
          "enabled" => false,
          "fallbackPriority" => 2
        }
      }
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get cli_backends_path
    end

    assert_response :success
    mock_client.verify
  end

  test "update requires backend_id" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      patch cli_backends_path, params: { backend_id: "" }
    end

    assert_redirected_to cli_backends_path
    assert_match(/required/i, flash[:alert])
  end

  test "update patches backend config" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch cli_backends_path, params: {
        backend_id: "claude-cli",
        command: "claude",
        enabled: "true",
        fallback_priority: "1"
      }
    end

    assert_redirected_to cli_backends_path
    assert_match(/updated/, flash[:notice])
    mock_client.verify
  end

  test "handles gateway error on update" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "error" => "Gateway timeout" }, raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch cli_backends_path, params: {
        backend_id: "claude-cli",
        command: "claude"
      }
    end

    assert_redirected_to cli_backends_path
    assert_match(/Failed/, flash[:alert])
    mock_client.verify
  end

  test "handles empty config gracefully" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {})

    OpenclawGatewayClient.stub(:new, mock_client) do
      get cli_backends_path
    end

    assert_response :success
    mock_client.verify
  end
end
