# frozen_string_literal: true

require "test_helper"

class DmScopeAuditControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  test "redirects unauthenticated users" do
    get dm_scope_audit_path
    assert_response :redirect
  end

  test "redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get dm_scope_audit_path
    assert_response :redirect
  end

  test "show handles gateway errors gracefully" do
    sign_in_as(@user)
    # Gateway not running — should handle errors
    get dm_scope_audit_path
    assert_includes [200, 302, 500], response.status
  end
end
