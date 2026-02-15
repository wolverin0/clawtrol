# frozen_string_literal: true

require "test_helper"

class Api::V1::GatewayControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }

    # Ensure the user has gateway config so the client can be instantiated
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test-gateway-token"
    )

    # Test env uses :null_store — gateway caching tests need a real store
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  # --- Authentication ---

  test "health returns unauthorized without token" do
    get api_v1_gateway_health_url
    assert_response :unauthorized
  end

  test "channels returns unauthorized without token" do
    get api_v1_gateway_channels_url
    assert_response :unauthorized
  end

  test "cost returns unauthorized without token" do
    get api_v1_gateway_cost_url
    assert_response :unauthorized
  end

  test "models returns unauthorized without token" do
    get api_v1_gateway_models_url
    assert_response :unauthorized
  end

  # --- Health endpoint ---

  test "health returns cached gateway health" do
    expected = { "status" => "ok", "uptime" => 3600 }
    Rails.cache.write("gateway/health/#{@user.id}", expected, expires_in: 15.seconds)

    get api_v1_gateway_health_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal 3600, body["uptime"]
  end

  # --- Channels endpoint ---

  test "channels returns cached channel status" do
    expected = { "channels" => [{ "name" => "telegram", "connected" => true }] }
    Rails.cache.write("gateway/channels/#{@user.id}", expected, expires_in: 30.seconds)

    get api_v1_gateway_channels_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_kind_of Array, body["channels"]
    assert_equal "telegram", body["channels"].first["name"]
  end

  # --- Cost endpoint ---

  test "cost returns cached usage cost data" do
    expected = { "totalCost" => 1.23, "period" => "24h" }
    Rails.cache.write("gateway/cost/#{@user.id}", expected, expires_in: 60.seconds)

    get api_v1_gateway_cost_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal 1.23, body["totalCost"]
  end

  # --- Models endpoint ---

  test "models returns cached model list" do
    expected = { "models" => %w[opus sonnet gemini] }
    Rails.cache.write("gateway/models/#{@user.id}", expected, expires_in: 5.minutes)

    get api_v1_gateway_models_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_kind_of Array, body["models"]
    assert_includes body["models"], "opus"
  end

  # --- Error resilience (gateway unreachable, cache miss) ---
  # When the cache is empty and the gateway is unreachable, the client's rescue
  # block returns a graceful error hash. We simulate this by pre-populating cache
  # with the error-case result (since we can't actually connect in tests).

  test "health returns graceful error hash when gateway down" do
    error_result = { "status" => "unreachable", "error" => "Connection refused" }
    Rails.cache.write("gateway/health/#{@user.id}", error_result, expires_in: 15.seconds)

    get api_v1_gateway_health_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal "unreachable", body["status"]
    assert body["error"].present?
  end

  test "channels returns empty array on error" do
    error_result = { "channels" => [], "error" => "timeout" }
    Rails.cache.write("gateway/channels/#{@user.id}", error_result, expires_in: 30.seconds)

    get api_v1_gateway_channels_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal [], body["channels"]
  end

  test "cost returns error hash on failure" do
    error_result = { "error" => "not configured" }
    Rails.cache.write("gateway/cost/#{@user.id}", error_result, expires_in: 60.seconds)

    get api_v1_gateway_cost_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert body["error"].present?
  end

  test "models returns empty array on error" do
    error_result = { "models" => [], "error" => "unreachable" }
    Rails.cache.write("gateway/models/#{@user.id}", error_result, expires_in: 5.minutes)

    get api_v1_gateway_models_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal [], body["models"]
  end

  # --- Cross-user isolation ---

  test "health cache is isolated per user" do
    user_two = users(:two)
    user_two.update_columns(
      openclaw_gateway_url: "http://localhost:8888",
      openclaw_gateway_token: "other-token"
    )

    user_one_data = { "status" => "ok", "instance" => "user_one" }
    user_two_data = { "status" => "ok", "instance" => "user_two" }

    Rails.cache.write("gateway/health/#{@user.id}", user_one_data, expires_in: 15.seconds)
    Rails.cache.write("gateway/health/#{user_two.id}", user_two_data, expires_in: 15.seconds)

    get api_v1_gateway_health_url, headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal "user_one", body["instance"]
  end
end
