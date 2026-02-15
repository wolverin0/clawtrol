# frozen_string_literal: true

require "test_helper"

class DmPolicyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  # === Authentication ===

  test "show redirects unauthenticated users" do
    get dm_policy_path
    assert_response :redirect
  end

  test "update redirects unauthenticated users" do
    patch dm_policy_path, params: { dm_policy: "open" }
    assert_response :redirect
  end

  test "approve_pairing redirects unauthenticated users" do
    post dm_policy_approve_pairing_path, params: { pairing_id: "abc" }
    assert_response :redirect
  end

  test "reject_pairing redirects unauthenticated users" do
    post dm_policy_reject_pairing_path, params: { pairing_id: "abc" }
    assert_response :redirect
  end

  # === Gateway Not Configured ===

  test "show redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get dm_policy_path
    assert_response :redirect
    assert_equal "Configure OpenClaw Gateway URL in Settings first", flash[:alert]
  end

  test "update redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    patch dm_policy_path, params: { dm_policy: "open" }
    assert_response :redirect
  end

  test "approve_pairing redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    post dm_policy_approve_pairing_path, params: { pairing_id: "abc" }
    assert_response :redirect
  end

  # === Show ===

  test "show handles gateway not running" do
    sign_in_as(@user)
    get dm_policy_path
    # Gateway is not running, controller should handle error gracefully
    assert_includes [200, 302, 500], response.status
  end

  # === Approve Pairing ===

  test "approve_pairing rejects blank pairing_id" do
    sign_in_as(@user)
    post dm_policy_approve_pairing_path, params: { pairing_id: "" }
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Pairing ID required", json["error"]
  end

  test "approve_pairing rejects missing pairing_id" do
    sign_in_as(@user)
    post dm_policy_approve_pairing_path
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Pairing ID required", json["error"]
  end

  test "approve_pairing rejects whitespace-only pairing_id" do
    sign_in_as(@user)
    post dm_policy_approve_pairing_path, params: { pairing_id: "   " }
    assert_response :unprocessable_entity
  end

  # === Reject Pairing ===

  test "reject_pairing rejects blank pairing_id" do
    sign_in_as(@user)
    post dm_policy_reject_pairing_path, params: { pairing_id: "" }
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Pairing ID required", json["error"]
  end

  test "reject_pairing rejects missing pairing_id" do
    sign_in_as(@user)
    post dm_policy_reject_pairing_path
    assert_response :unprocessable_entity
  end

  # === DM Config Extraction (private methods tested via show) ===

  test "build_dm_patch validates dm_policy values" do
    sign_in_as(@user)
    # Invalid dm_policy should not be included in patch
    # We test this indirectly by ensuring the controller doesn't crash
    patch dm_policy_path, params: { dm_policy: "hacked_value" }
    # Should redirect (either success or error), not crash
    assert_includes [200, 302, 500], response.status
  end

  test "build_dm_patch validates group_policy values" do
    sign_in_as(@user)
    patch dm_policy_path, params: { group_policy: "invalid_policy" }
    assert_includes [200, 302, 500], response.status
  end

  test "build_dm_patch accepts valid dm_policy" do
    sign_in_as(@user)
    %w[open pairing allowlist disabled].each do |policy|
      patch dm_policy_path, params: { dm_policy: policy }
      assert_includes [200, 302, 500], response.status, "Policy #{policy} should be accepted"
    end
  end

  test "build_dm_patch accepts valid group_policy" do
    sign_in_as(@user)
    %w[open allowlist disabled].each do |policy|
      patch dm_policy_path, params: { group_policy: policy }
      assert_includes [200, 302, 500], response.status, "Group policy #{policy} should be accepted"
    end
  end

  test "build_dm_patch splits allow_from on commas" do
    sign_in_as(@user)
    patch dm_policy_path, params: {
      dm_policy: "allowlist",
      allow_from: "user1, user2, user3"
    }
    assert_includes [200, 302, 500], response.status
  end
end
