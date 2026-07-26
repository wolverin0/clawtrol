# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # --- Authentication ---

  test "show requires authentication" do
    get settings_path
    assert_response :redirect
  end

  test "show renders when authenticated" do
    sign_in_as(@user)
    get settings_path
    assert_response :success
  end

  # --- Profile update ---

  test "update changes user settings" do
    sign_in_as(@user)
    patch settings_path, params: {
      user: { agent_name: "TestAgent", agent_emoji: "🤖" }
    }
    assert_redirected_to settings_path
    @user.reload
    assert_equal "TestAgent", @user.agent_name
    assert_equal "🤖", @user.agent_emoji
  end

  test "update saves Hermes backend settings" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        orchestration_mode: "dual",
        preferred_agent_platform: "hermes",
        hermes_gateway_url: "https://hermes.example.test",
        hermes_gateway_token: "gateway-token",
        hermes_hooks_token: "hooks-token",
        hermes_home: "~/.hermes",
        hermes_profile: "ops"
      }
    }

    assert_redirected_to settings_path
    @user.reload
    assert_equal "dual", @user.orchestration_mode
    assert_equal "hermes", @user.preferred_agent_platform
    assert_equal "https://hermes.example.test", @user.hermes_gateway_url
    assert_equal "gateway-token", @user.hermes_gateway_token
    assert_equal "hooks-token", @user.hermes_hooks_token
    assert_equal "~/.hermes", @user.hermes_home
    assert_equal "ops", @user.hermes_profile
  end

  test "settings page exposes Hermes backend controls" do
    sign_in_as(@user)

    get settings_path

    assert_response :success
    assert_select "option[value=?]", "hermes_only"
    assert_select "select[name=?]", "user[preferred_agent_platform]"
    assert_select "input[name=?]", "user[hermes_home]"
    assert_select "input[name=?]", "user[hermes_gateway_token]"
  end

  # --- SSRF protection in test_connection ---

  test "test_connection blocks localhost gateway URL" do
    sign_in_as(@user)
    @user.update!(openclaw_gateway_url: "http://127.0.0.1:4001")
    post test_connection_settings_path
    json = JSON.parse(response.body)
    assert_equal false, json["gateway_reachable"]
    assert_match(/restricted/i, json["error"].to_s)
  end

  test "test_connection blocks link-local gateway URL" do
    sign_in_as(@user)
    @user.update!(openclaw_gateway_url: "http://169.254.169.254")
    post test_connection_settings_path
    json = JSON.parse(response.body)
    assert_equal false, json["gateway_reachable"]
    assert_match(/restricted|resolve/i, json["error"].to_s)
  end

  test "test_connection blocks ftp scheme" do
    sign_in_as(@user)
    # ftp:// is rejected at model validation level — can't save an invalid scheme
    assert_not @user.update(openclaw_gateway_url: "ftp://evil.com")
    assert_includes @user.errors[:openclaw_gateway_url], "must be a valid http(s) URL"
  end

  test "test_connection handles missing gateway URL gracefully" do
    sign_in_as(@user)
    @user.update!(openclaw_gateway_url: nil)
    post test_connection_settings_path
    json = JSON.parse(response.body)
    assert_equal false, json["gateway_reachable"]
    assert_equal false, json["webhook_configured"]
  end

  # --- API token regeneration ---

  test "regenerate_api_token creates new token and removes old ones" do
    sign_in_as(@user)
    @user.api_tokens.create!(name: "Old Token")
    old_count = @user.api_tokens.count
    assert old_count >= 1

    post regenerate_api_token_settings_path
    assert_redirected_to settings_path

    @user.reload
    # Should have exactly 1 token after regeneration (old destroyed, new created)
    assert_equal 1, @user.api_tokens.count

    # Token should NOT appear in notice text (security fix)
    refute_match(/[a-zA-Z0-9]{20,}/, flash[:notice].to_s)
    # Token should be in a separate flash key for one-time display
    assert flash[:new_api_token].present?
    assert flash[:new_api_token].length > 20
  end
end
