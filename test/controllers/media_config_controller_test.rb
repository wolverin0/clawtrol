# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class MediaConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get media_config_path
    assert_response :redirect
  end

  test "show renders media config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {
      "tools" => { "media" => {
        "audio" => { "enabled" => true, "provider" => "openai", "model" => "whisper-1" },
        "video" => { "enabled" => true, "provider" => "google" },
        "image" => { "enabled" => true }
      } }
    })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get media_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "show handles gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "unreachable" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get media_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "update audio config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch media_config_path, params: {
        audio: { enabled: "true", provider: "openai", model: "whisper-1", maxFileSizeMb: "50" }
      }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update video and image config together" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch media_config_path, params: {
        video: { enabled: "false", extractFrames: "false" },
        image: { enabled: "true", model: "gpt-4o" }
      }
      assert_response :redirect
    end
    mock_client.verify
  end
end
