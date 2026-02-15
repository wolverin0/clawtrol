# frozen_string_literal: true

require "test_helper"

# Batch authentication tests for controllers that were missing test files entirely.
# Ensures every page requires authentication (no accidental public access).
class MissingControllerAuthTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test-token"
    )
  end

  # [label, actual_path]
  PROTECTED_GET_PAGES = {
    "Canvas"              => "/canvas",
    "CLI Backends"        => "/cli-backends",
    "Compaction Config"   => "/compaction-config",
    "Config Hub"          => "/config",
    "Discord Config"      => "/discord_config",
    "Hooks Dashboard"     => "/hooks-dashboard",
    "Hot Reload"          => "/hot_reload",
    "Identity Config"     => "/identity-config",
    "Logging Config"      => "/logging_config",
    "Media Config"        => "/media-config",
    "Memory Dashboard"    => "/memory",
    "Message Queue Config"=> "/message-queue",
    "Send Policy"         => "/send-policy",
    "Session Maintenance" => "/session-maintenance",
    "Typing Config"       => "/typing-config"
  }.freeze

  PROTECTED_GET_PAGES.each do |label, path|
    test "#{label} (#{path}) requires authentication" do
      get path
      assert_response :redirect, "#{label} at #{path} should redirect unauthenticated users"
    end
  end

  # Verify authenticated access doesn't 404 (route exists)
  PROTECTED_GET_PAGES.each do |label, path|
    test "#{label} (#{path}) returns non-404 when authenticated" do
      sign_in_as(@user)
      get path
      # Gateway may be down (500/502) or redirect to settings (302), but should NOT 404
      refute_equal 404, response.status,
        "#{label} returned 404 — route may be missing"
    end
  end
end
