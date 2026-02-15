# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class TypingConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get typing_config_path
    assert_response :redirect
  end

  test "show redirects when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get typing_config_path
    assert_response :redirect
  end

  test "show renders typing config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "typing" => { "mode" => "thinking", "intervalMs" => 5000 } })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get typing_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "show handles gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "unreachable" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get typing_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "update changes typing mode" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch typing_config_path, params: { mode: "message" }
      assert_response :redirect
      assert_redirected_to typing_config_path
    end
    mock_client.verify
  end

  test "update clamps interval_ms" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch typing_config_path, params: { interval_ms: "100" } # below 1000 min
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update ignores invalid mode" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch typing_config_path, params: { mode: "hacker" }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update reports gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "error" => "failed" }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch typing_config_path, params: { mode: "never" }
      assert_response :redirect
      follow_redirect!
    end
    mock_client.verify
  end
end
