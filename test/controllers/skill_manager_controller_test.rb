# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SkillManagerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  # ── GET /skills (index) ────────────────────────────────────────────
  test "index requires authentication" do
    sign_out
    get skill_manager_path
    assert_response :redirect
  end

  test "index redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get skill_manager_path
    assert_response :redirect
  end

  test "index renders installed skills" do
    mock_config = { "config" => { "skills" => { "weather" => { "enabled" => true, "description" => "Weather forecasts" } } } }
    mock_health = { "status" => "ok" }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)
    mock_client.expect(:health, mock_health)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get skill_manager_path
      assert_response :success
    end
    mock_client.verify
  end

  test "index includes bundled skills when allowBundled not false" do
    mock_config = { "config" => { "skills" => {} } }
    mock_health = { "status" => "ok" }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)
    mock_client.expect(:health, mock_health)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get skill_manager_path
      assert_response :success
      # Should still include bundled skills like weather, github, etc.
      assert_match(/weather/i, response.body)
    end
    mock_client.verify
  end

  # ── POST /skills/:name/toggle ──────────────────────────────────────
  test "toggle enables a skill" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "skills" => {} } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post skill_toggle_path("weather"), params: { enabled: "true" }
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "toggle rejects path traversal in skill name" do
    post skill_toggle_path("etcpasswd"), params: { enabled: "true" }
    # The sanitizer strips non-alphanumeric chars, so "../../etc" becomes "etc"
    # But we need to ensure it's handled — this will hit the gateway
    # For actual traversal, the name would be sanitized to empty
    # Test with truly invalid name:
    post "/skills/#{CGI.escape("../")}/toggle", params: { enabled: "true" }
    assert_includes [404, 422], response.status
  end

  test "toggle rejects empty skill name after sanitization" do
    # Special chars only => sanitized to empty; route may 404 or controller may 422
    post skill_toggle_path("..."), params: { enabled: "true" }
    assert_includes [404, 422], response.status
  end

  # ── POST /skills/:name/configure ───────────────────────────────────
  test "configure updates env vars with valid JSON" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "skills" => { "weather" => {} } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post skill_configure_path("weather"), params: { env_vars: '{"API_KEY": "test123"}' }
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "configure rejects invalid JSON" do
    post skill_configure_path("weather"), params: { env_vars: "not json" }
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/invalid json/i, body["error"])
  end

  test "configure rejects nested object env vars" do
    post skill_configure_path("weather"), params: { env_vars: '{"nested": {"bad": true}}' }
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/invalid env/i, body["error"])
  end

  test "configure rejects oversized env values" do
    huge_value = "x" * 5000
    post skill_configure_path("weather"), params: { env_vars: "{\"KEY\": \"#{huge_value}\"}" }
    assert_response :unprocessable_entity
  end

  test "configure clears env when empty JSON object" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "skills" => { "weather" => { "env" => { "OLD" => "val" } } } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post skill_configure_path("weather"), params: { env_vars: "{}" }
      assert_response :success
    end
    mock_client.verify
  end

  # ── POST /skills/install ───────────────────────────────────────────
  test "install adds skill to config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "skills" => {} } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post skill_install_path, params: { skill_name: "new-skill" }
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "install rejects blank skill name" do
    post skill_install_path, params: { skill_name: "" }
    assert_response :unprocessable_entity
  end

  # ── DELETE /skills/:name ───────────────────────────────────────────
  test "uninstall removes skill from config" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "skills" => { "old-skill" => { "enabled" => true } } } })
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      delete skill_uninstall_path("old-skill")
      assert_response :success
      body = JSON.parse(response.body)
      assert body["success"]
    end
    mock_client.verify
  end

  test "uninstall rejects sanitized-empty name" do
    delete skill_uninstall_path("...")
    assert_includes [404, 422], response.status
  end

  # ── Gateway error handling ─────────────────────────────────────────
  test "toggle reports gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "config" => { "skills" => {} } })
    mock_client.expect(:config_patch, { "error" => "connection refused" }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post skill_toggle_path("weather"), params: { enabled: "true" }
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      refute body["success"]
      assert_match(/connection refused/, body["error"])
    end
    mock_client.verify
  end
end
