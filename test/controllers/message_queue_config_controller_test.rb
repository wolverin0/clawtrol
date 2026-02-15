# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class MessageQueueConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get message_queue_config_path
    assert_response :redirect
  end

  test "show renders queue config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {
      "routing" => { "queue" => { "mode" => "collect", "debounceMs" => 2000, "cap" => 10 } }
    })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get message_queue_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "update queue mode" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch message_queue_config_path, params: { mode: "immediate" }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update rejects invalid queue mode" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch message_queue_config_path, params: { mode: "hacker" }
      assert_response :redirect
      # Invalid mode silently ignored
    end
    mock_client.verify
  end

  test "update clamps debounce_ms" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch message_queue_config_path, params: { debounce_ms: "1" } # below 100
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update clamps cap" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch message_queue_config_path, params: { cap: "999" } # above 100
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update drop strategy" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch message_queue_config_path, params: { drop_strategy: "newest" }
      assert_response :redirect
    end
    mock_client.verify
  end
end
