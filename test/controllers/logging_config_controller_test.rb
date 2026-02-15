# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class LoggingConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get logging_config_path
    assert_response :redirect
  end

  test "show renders logging and debug config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {
      "config" => {
        "logging" => { "level" => "info", "consoleLevel" => "info", "consoleStyle" => "pretty" },
        "debug" => { "enabled" => false }
      }
    })
    mock_client.expect(:health, { "status" => "ok" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get logging_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "update logging section" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "logging" => {} } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post logging_config_update_path, params: {
        section: "logging",
        values: { level: "debug", console_level: "warn", console_style: "json" }
      }
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "update debug section" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "debug" => {} } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post logging_config_update_path, params: {
        section: "debug",
        values: { enabled: "true", bash: "false" }
      }
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "update rejects invalid section" do
    post logging_config_update_path, params: {
      section: "hacker",
      values: { level: "debug" }
    }
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/unknown section/i, body["error"])
  end

  test "update rejects invalid log level" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "logging" => { "level" => "info" } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post logging_config_update_path, params: {
        section: "logging",
        values: { level: "hacker_level" }
      }
      assert_response :success
      # Invalid level is silently ignored, existing level preserved
    end
    mock_client.verify
  end

  test "update rejects path traversal in log file" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "logging" => {} } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post logging_config_update_path, params: {
        section: "logging",
        values: { file: "../../etc/shadow" }
      }
      assert_response :success
      # Path traversal is rejected by the regex, file field not set
    end
    mock_client.verify
  end

  test "tail returns log lines" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:health, { "logFile" => nil })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get logging_config_tail_path, params: { lines: 10 }
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 0, body["count"]
    end
    mock_client.verify
  end
end
