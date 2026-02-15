# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ChannelConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get channel_config_path(channel: "mattermost")
    assert_response :redirect
  end

  test "show redirects for unsupported channel" do
    get channel_config_path(channel: "foobar")
    assert_response :redirect
  end

  test "show renders mattermost config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => { "mattermost" => { "chatmode" => "onmessage" } } } })
    mock_client.expect(:channels_status, { "mattermost" => { "connected" => true } })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get channel_config_path(channel: "mattermost")
      assert_response :success
    end
    mock_client.verify
  end

  test "show renders slack config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => { "slack" => { "socketMode" => true } } } })
    mock_client.expect(:channels_status, { "slack" => { "connected" => true } })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get channel_config_path(channel: "slack")
      assert_response :success
    end
    mock_client.verify
  end

  test "show renders signal config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => { "signal" => { "reactionMode" => "off" } } } })
    mock_client.expect(:channels_status, { "signal" => { "connected" => false } })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get channel_config_path(channel: "signal")
      assert_response :success
    end
    mock_client.verify
  end

  test "update mattermost config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => { "mattermost" => {} } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post channel_config_update_path(channel: "mattermost"), params: {
        values: { chat_mode: "oncall", server_url: "https://mattermost.example.com", team: "main" }
      }
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "update slack config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => { "slack" => {} } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post channel_config_update_path(channel: "slack"), params: {
        values: { socket_mode: "true", thread_mode: "broadcast" }
      }
      assert_response :success
    end
    mock_client.verify
  end

  test "update signal config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => { "signal" => {} } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post channel_config_update_path(channel: "signal"), params: {
        values: { reaction_mode: "all", group_handling: "mention_only" }
      }
      assert_response :success
    end
    mock_client.verify
  end

  test "update reports gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "channels" => {} } })
    mock_client.expect(:config_patch, { "error" => "connection refused" }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post channel_config_update_path(channel: "mattermost"), params: {
        values: { chat_mode: "oncall" }
      }
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/connection refused/, body["error"])
    end
    mock_client.verify
  end
end
