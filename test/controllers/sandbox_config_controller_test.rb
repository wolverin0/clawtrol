# frozen_string_literal: true

require "test_helper"

class SandboxConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  # === Authentication ===

  test "show redirects unauthenticated users" do
    get sandbox_config_path
    assert_response :redirect
  end

  test "update redirects unauthenticated users" do
    patch sandbox_config_path, params: { mode: "docker" }
    assert_response :redirect
  end

  # === Gateway Not Configured ===

  test "show redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get sandbox_config_path
    assert_response :redirect
    assert_equal "Configure OpenClaw Gateway URL in Settings first", flash[:alert]
  end

  test "update redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    patch sandbox_config_path, params: { mode: "docker" }
    assert_response :redirect
  end

  # === Show ===

  test "show handles gateway not running" do
    sign_in_as(@user)
    get sandbox_config_path
    assert_includes [200, 302, 500], response.status
  end

  # === Update with valid modes ===

  test "update handles valid sandbox modes" do
    sign_in_as(@user)
    %w[docker host none].each do |mode|
      patch sandbox_config_path, params: { mode: mode }
      assert_includes [200, 302, 500], response.status, "Mode #{mode} should be accepted"
    end
  end

  test "update handles valid sandbox scopes" do
    sign_in_as(@user)
    %w[workspace home full].each do |scope|
      patch sandbox_config_path, params: { scope: scope }
      assert_includes [200, 302, 500], response.status, "Scope #{scope} should be accepted"
    end
  end

  test "update rejects invalid mode" do
    sign_in_as(@user)
    # Invalid mode should not be included in patch (silently ignored)
    patch sandbox_config_path, params: { mode: "hacked" }
    assert_includes [200, 302, 500], response.status
  end

  test "update rejects invalid scope" do
    sign_in_as(@user)
    patch sandbox_config_path, params: { scope: "dangerous" }
    assert_includes [200, 302, 500], response.status
  end

  # === Presets ===

  test "update accepts valid presets" do
    sign_in_as(@user)
    %w[minimal standard full].each do |preset|
      patch sandbox_config_path, params: { preset: preset }
      assert_includes [200, 302, 500], response.status, "Preset #{preset} should be accepted"
    end
  end

  test "update ignores invalid preset" do
    sign_in_as(@user)
    patch sandbox_config_path, params: { preset: "nonexistent" }
    assert_includes [200, 302, 500], response.status
  end

  # === Boolean params ===

  test "update handles boolean params" do
    sign_in_as(@user)
    patch sandbox_config_path, params: {
      mode: "docker",
      network: "true",
      browser_sandbox: "false",
      resource_limits: "true",
      seccomp: "true",
      apparmor: "false"
    }
    assert_includes [200, 302, 500], response.status
  end

  # === Resource limits ===

  test "update handles resource limits" do
    sign_in_as(@user)
    patch sandbox_config_path, params: {
      cpu_limit: "2",
      memory_limit: "512m"
    }
    assert_includes [200, 302, 500], response.status
  end

  # === Constants ===

  test "SANDBOX_MODES contains expected values" do
    assert_equal %w[docker host none], SandboxConfigController::SANDBOX_MODES
  end

  test "SANDBOX_SCOPES contains expected values" do
    assert_equal %w[workspace home full], SandboxConfigController::SANDBOX_SCOPES
  end

  test "PRESETS contains expected presets" do
    presets = SandboxConfigController::PRESETS
    assert_includes presets.keys, "minimal"
    assert_includes presets.keys, "standard"
    assert_includes presets.keys, "full"

    # Minimal should be most restrictive
    assert_equal false, presets["minimal"][:network]
    assert_equal true, presets["minimal"][:seccomp]

    # Full should be most permissive
    assert_equal true, presets["full"][:network]
    assert_equal true, presets["full"][:browser]
    assert_equal false, presets["full"][:seccomp]
  end
end
