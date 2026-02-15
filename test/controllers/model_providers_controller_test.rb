# frozen_string_literal: true

require "test_helper"

class ModelProvidersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:18080",
      openclaw_gateway_token: "test-token"
    )
  end

  # ── Auth ──────────────────────────────────────────────────

  test "index requires authentication" do
    get model_providers_path
    assert_response :redirect
  end

  test "update requires authentication" do
    patch model_providers_update_path, params: { provider_id: "test" }
    assert_response :redirect
  end

  test "test_provider requires authentication" do
    post model_providers_test_path, params: { base_url: "https://example.com", model: "test" }
    assert_response :redirect
  end

  # ── Test Provider: Input Validation ───────────────────────

  test "test_provider requires base_url and model" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "", model: "" }
    assert_response :unprocessable_entity

    json = JSON.parse(response.body)
    assert_match /required/i, json["error"]
  end

  test "test_provider requires model even with base_url" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "https://api.example.com/v1", model: "" }
    assert_response :unprocessable_entity
  end

  # ── Test Provider: SSRF Protection ────────────────────────

  test "test_provider blocks SSRF to private 192.168.x.x networks" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "http://192.168.1.1/v1", model: "test" }
    assert_response :forbidden

    json = JSON.parse(response.body)
    assert_match /private.*internal|blocked/i, json["error"]
  end

  test "test_provider blocks SSRF to localhost" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "http://localhost:8080/v1", model: "test" }
    assert_response :forbidden
  end

  test "test_provider blocks SSRF to 10.x networks" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "http://10.0.0.1/v1", model: "test" }
    assert_response :forbidden
  end

  test "test_provider blocks SSRF to link-local addresses" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "http://169.254.169.254/v1", model: "test" }
    assert_response :forbidden
  end

  test "test_provider blocks SSRF to 127.0.0.1" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "http://127.0.0.1:11434/v1", model: "test" }
    assert_response :forbidden
  end

  test "test_provider blocks SSRF to .internal TLD" do
    sign_in_as(@user)

    post model_providers_test_path, params: { base_url: "http://backend.internal/v1", model: "test" }
    assert_response :forbidden
  end

  # ── Update: Input Validation ──────────────────────────────

  test "update requires provider_id" do
    sign_in_as(@user)
    patch model_providers_update_path, params: { provider_id: "" }
    assert_redirected_to model_providers_path
  end
end
