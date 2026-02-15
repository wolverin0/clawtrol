# frozen_string_literal: true

require "test_helper"

class StatusControllerTest < ActionDispatch::IntegrationTest
  test "returns JSON status without authentication" do
    get status_path, headers: { "Accept" => "application/json" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "ok", json["clawdeck"]
    assert json["timestamp"].present?
    assert json.key?("gateway")
    assert json.key?("uptime")
  end

  test "returns HTML status page without authentication" do
    get status_path
    assert_response :success
    assert_match /ClawDeck Status/, response.body
  end

  test "does not expose sensitive data" do
    get status_path, headers: { "Accept" => "application/json" }
    assert_response :success

    body = response.body
    # Should NOT contain tokens, passwords, or user info
    refute_match(/token/i, body)
    refute_match(/password/i, body)
    refute_match(/email/i, body)
    refute_match(/Bearer/i, body)
  end

  test "includes clawdeck version" do
    get status_path, headers: { "Accept" => "application/json" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["clawdeck_version"].present?
  end

  test "handles missing gateway gracefully" do
    # No users with gateway configured in test fixtures
    get status_path, headers: { "Accept" => "application/json" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "offline", json.dig("gateway", "status")
  end
end
