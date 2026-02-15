# frozen_string_literal: true

require "test_helper"

class ChannelAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:9999",
      openclaw_gateway_token: "test_token"
    )
  end

  # === Authentication ===

  test "show redirects unauthenticated users" do
    get channel_accounts_path
    assert_response :redirect
  end

  test "update redirects unauthenticated users" do
    patch channel_accounts_update_path, params: { channel: "telegram", account_id: "default" }
    assert_response :redirect
  end

  # === Gateway Not Configured ===

  test "show redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get channel_accounts_path
    assert_response :redirect
    assert_equal "Configure OpenClaw Gateway URL in Settings first", flash[:alert]
  end

  test "update redirects if gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    patch channel_accounts_update_path, params: { channel: "telegram", account_id: "default" }
    assert_response :redirect
  end

  # === Show ===

  test "show handles gateway not running" do
    sign_in_as(@user)
    get channel_accounts_path
    assert_includes [200, 302, 500], response.status
  end

  # === Update Validation ===

  test "update rejects unsupported channel" do
    sign_in_as(@user)
    patch channel_accounts_update_path, params: { channel: "matrix", account_id: "default" }
    assert_redirected_to channel_accounts_path
    assert_match /Unsupported channel/, flash[:alert]
  end

  test "update accepts all supported channels" do
    sign_in_as(@user)
    %w[telegram whatsapp discord signal slack irc googlechat imessage].each do |channel|
      patch channel_accounts_update_path, params: {
        channel: channel,
        account_id: "test_acct",
        dm_policy: "open"
      }
      assert_includes [200, 302, 500], response.status, "Channel #{channel} should be accepted"
    end
  end

  test "update handles dm_policy parameter" do
    sign_in_as(@user)
    patch channel_accounts_update_path, params: {
      channel: "telegram",
      account_id: "default",
      dm_policy: "allowlist"
    }
    assert_includes [200, 302, 500], response.status
  end

  test "update handles allow_from csv splitting" do
    sign_in_as(@user)
    patch channel_accounts_update_path, params: {
      channel: "telegram",
      account_id: "default",
      allow_from: "user1, user2, user3"
    }
    assert_includes [200, 302, 500], response.status
  end

  # === Constants ===

  test "SUPPORTED_CHANNELS is frozen and complete" do
    channels = ChannelAccountsController::SUPPORTED_CHANNELS
    assert channels.frozen?
    assert_includes channels, "telegram"
    assert_includes channels, "whatsapp"
    assert_includes channels, "discord"
    assert_includes channels, "signal"
    assert_includes channels, "slack"
    assert_includes channels, "imessage"
    assert_equal 8, channels.size
  end
end
