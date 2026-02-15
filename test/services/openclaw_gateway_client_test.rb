# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class OpenclawGatewayClientTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:4040",
      openclaw_gateway_token: "test-token-12345"
    )
  end

  # --- Initialization ---

  test "returns error when gateway URL not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    client = OpenclawGatewayClient.new(@user)
    result = client.health
    assert_equal "unreachable", result["status"]
    assert_match(/not configured/, result["error"])
  end

  test "returns error when gateway token not configured" do
    @user.update_columns(openclaw_gateway_token: nil)
    client = OpenclawGatewayClient.new(@user)
    result = client.health
    assert_equal "unreachable", result["status"]
    assert_match(/not configured/, result["error"])
  end

  # --- URL Validation ---

  test "rejects example URLs" do
    @user.update_columns(openclaw_gateway_url: "http://example.com/api")
    client = OpenclawGatewayClient.new(@user)
    result = client.health
    assert_equal "unreachable", result["status"]
    assert_match(/placeholder|example/i, result["error"])
  end

  test "rejects non-HTTP URLs via error hash" do
    @user.update_columns(openclaw_gateway_url: "ftp://localhost:4040")
    client = OpenclawGatewayClient.new(@user)
    result = client.health
    assert_equal "unreachable", result["status"]
  end

  test "rejects localhost without explicit port" do
    @user.update_columns(openclaw_gateway_url: "http://localhost")
    client = OpenclawGatewayClient.new(@user)
    result = client.health
    assert_equal "unreachable", result["status"]
    assert_match(/port/, result["error"])
  end

  # --- Error Handling (graceful) ---

  test "health returns error hash when gateway unreachable" do
    client = OpenclawGatewayClient.new(@user)
    result = client.health
    assert_equal "unreachable", result["status"]
    assert result["error"].present?
  end

  test "channels_status returns error on failure" do
    client = OpenclawGatewayClient.new(@user)
    result = client.channels_status
    assert result.key?("error")
  end

  test "usage_cost returns error on failure" do
    client = OpenclawGatewayClient.new(@user)
    result = client.usage_cost
    assert result.key?("error")
  end

  test "models_list returns empty array on error" do
    client = OpenclawGatewayClient.new(@user)
    result = client.models_list
    assert_equal [], result["models"]
    assert result["error"].present?
  end

  test "agents_list returns empty array on error" do
    client = OpenclawGatewayClient.new(@user)
    result = client.agents_list
    assert_equal [], result["agents"]
    assert result["error"].present?
  end

  test "nodes_status returns empty array on error" do
    client = OpenclawGatewayClient.new(@user)
    result = client.nodes_status
    assert_equal [], result["nodes"]
    assert result["error"].present?
  end

  test "sessions_list returns empty array on error" do
    client = OpenclawGatewayClient.new(@user)
    result = client.sessions_list
    assert_equal [], result["sessions"]
    assert result["error"].present?
  end

  test "cron_list returns empty on error" do
    client = OpenclawGatewayClient.new(@user)
    result = client.cron_list
    assert_equal [], result["jobs"]
  end

  test "plugins_status returns empty when gateway unreachable" do
    client = OpenclawGatewayClient.new(@user)
    result = client.plugins_status
    assert_equal [], result["plugins"]
    # gateway_version may be nil when health returns unreachable
    assert_nil result["gateway_version"]
  end

  # --- Plugin Extraction ---

  test "extract_plugins from health data with hash entries" do
    client = OpenclawGatewayClient.new(@user)
    health = {
      "loadedPlugins" => [
        { "name" => "voice-call", "enabled" => true, "version" => "1.0.0" },
        { "name" => "memory-lancedb", "enabled" => false, "version" => "0.5.0" }
      ]
    }

    plugins = client.send(:extract_plugins, health, {})
    assert_equal 2, plugins.size
    assert_equal "voice-call", plugins[0]["name"]
    assert_equal true, plugins[0]["enabled"]
    assert_equal "memory-lancedb", plugins[1]["name"]
    assert_equal false, plugins[1]["enabled"]
  end

  test "extract_plugins from health data with string entries" do
    client = OpenclawGatewayClient.new(@user)
    health = { "plugins" => ["telegram", "discord"] }

    plugins = client.send(:extract_plugins, health, {})
    assert_equal 2, plugins.size
    assert_equal "telegram", plugins[0]["name"]
    assert_equal true, plugins[0]["enabled"]
  end

  test "extract_plugins falls back to config data" do
    client = OpenclawGatewayClient.new(@user)
    health = {}
    config = {
      "config" => {
        "plugins" => [
          { "name" => "matrix", "enabled" => true }
        ]
      }
    }

    plugins = client.send(:extract_plugins, health, config)
    assert_equal 1, plugins.size
    assert_equal "matrix", plugins[0]["name"]
  end

  test "extract_plugins deduplicates by name" do
    client = OpenclawGatewayClient.new(@user)
    health = { "plugins" => ["telegram", "telegram"] }

    plugins = client.send(:extract_plugins, health, {})
    assert_equal 1, plugins.size
  end

  test "extract_plugins handles empty health and config" do
    client = OpenclawGatewayClient.new(@user)
    plugins = client.send(:extract_plugins, {}, {})
    assert_equal [], plugins
  end
end
