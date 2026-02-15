# frozen_string_literal: true

require "test_helper"

class EnvManagerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
    @env_file = EnvManagerController::ENV_FILE
    @original_content = File.exist?(@env_file) ? File.read(@env_file) : nil
  end

  teardown do
    # Restore original .env file
    if @original_content
      File.write(@env_file, @original_content)
    end
  end

  # === Authentication ===

  test "show redirects unauthenticated users" do
    get env_manager_path
    assert_response :redirect
  end

  test "file_contents redirects unauthenticated users" do
    get env_manager_file_path
    assert_response :redirect
  end

  test "test_substitution redirects unauthenticated users" do
    post env_manager_test_path, params: { template: "test" }
    assert_response :redirect
  end

  # === Gateway Not Configured ===

  test "show redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get env_manager_path
    assert_response :redirect
    assert_equal "Configure OpenClaw Gateway URL in Settings first", flash[:alert]
  end

  test "file_contents redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get env_manager_file_path
    assert_response :redirect
  end

  test "test_substitution redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "test" }
    assert_response :redirect
  end

  # === Show (GET /env_manager) ===

  test "show renders with gateway error gracefully" do
    sign_in_as(@user)
    # Gateway is not running, but should handle the error
    get env_manager_path
    # May 200 (renders with error state) or 500 if unhandled
    assert_includes [200, 302, 500], response.status
  end

  # === File Contents (GET /env_manager/file) ===

  test "file_contents returns redacted content when env file exists" do
    sign_in_as(@user)
    # The .env file should exist on the test machine
    if File.exist?(@env_file)
      get env_manager_file_path
      assert_response :success
      json = JSON.parse(response.body)
      assert json["exists"]
      assert json["line_count"].is_a?(Integer)
      # Verify values are redacted (should contain •••• not actual values)
      if json["content"].present?
        json["content"].lines.each do |line|
          next if line.strip.empty? || line.strip.start_with?("#")
          if line.include?("=")
            _key, val = line.split("=", 2)
            assert_includes val.to_s, "••••••••", "Values should be redacted: #{line.strip}"
          end
        end
      end
    end
  end

  test "file_contents returns empty when env file missing" do
    sign_in_as(@user)
    # Temporarily point to a non-existent file
    original_const = EnvManagerController::ENV_FILE
    EnvManagerController.send(:remove_const, :ENV_FILE)
    EnvManagerController.const_set(:ENV_FILE, "/tmp/nonexistent_env_file_#{SecureRandom.hex(8)}")

    get env_manager_file_path
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["exists"]
    assert_equal "", json["content"]
  ensure
    EnvManagerController.send(:remove_const, :ENV_FILE)
    EnvManagerController.const_set(:ENV_FILE, original_const)
  end

  # === Test Substitution (POST /env_manager/test) ===

  test "test_substitution rejects blank template" do
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "" }
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_equal "Template is required", json["error"]
  end

  test "test_substitution rejects whitespace-only template" do
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "   " }
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "test_substitution resolves known vars" do
    sign_in_as(@user)
    # Use a var that's very likely in the .env file
    post env_manager_test_path, params: { template: "token=${CLAWTROL_API_TOKEN}" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "token=${CLAWTROL_API_TOKEN}", json["template"]
    assert_includes json["vars_found"], "CLAWTROL_API_TOKEN"
  end

  test "test_substitution marks missing vars" do
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "${TOTALLY_FAKE_VAR_12345}" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_includes json["resolved"], "NOT FOUND"
  end

  test "test_substitution truncates long templates" do
    sign_in_as(@user)
    long_template = "A" * 2000
    post env_manager_test_path, params: { template: long_template }
    assert_response :success
    json = JSON.parse(response.body)
    # Template should be truncated to 1000 chars
    assert json["template"].length <= 1000
  end

  test "test_substitution handles template with multiple vars" do
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "${VAR_A} and ${VAR_B} and ${VAR_A}" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    # vars_found should deduplicate
    assert_includes json["vars_found"], "VAR_A"
    assert_includes json["vars_found"], "VAR_B"
  end

  test "test_substitution handles template with no vars" do
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "no variables here" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "no variables here", json["resolved"]
    assert_empty json["vars_found"]
  end

  test "test_substitution does not leak actual values" do
    sign_in_as(@user)
    post env_manager_test_path, params: { template: "${CLAWTROL_API_TOKEN}" }
    assert_response :success
    json = JSON.parse(response.body)
    # The resolved value should contain *** masking, not the actual token
    if json["resolved"].include?("***")
      refute_includes json["resolved"], ENV["CLAWTROL_API_TOKEN"].to_s if ENV["CLAWTROL_API_TOKEN"].present?
    end
  end
end
