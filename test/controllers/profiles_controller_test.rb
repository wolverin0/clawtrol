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

  test "update ignores retired direct-control settings" do
    sign_in_as(@user)
    original_values = @user.attributes.slice(
      "orchestration_mode",
      "preferred_agent_platform",
      "hermes_gateway_url",
      "hermes_home",
      "hermes_profile"
    )

    patch settings_path, params: {
      user: {
        agent_name: "PassiveOnly",
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
    assert_equal "PassiveOnly", @user.agent_name
    assert_equal original_values, @user.attributes.slice(*original_values.keys)
    refute_equal "gateway-token", @user.hermes_gateway_token
    refute_equal "hooks-token", @user.hermes_hooks_token
  end

  test "settings page exposes passive mirror notice without direct controls" do
    sign_in_as(@user)

    get settings_path

    assert_response :success
    assert_includes response.body, "Passive Hermes mirror"
    assert_select "select[name=?]", "user[preferred_agent_platform]", count: 0
    assert_select "input[name=?]", "user[hermes_home]", count: 0
    assert_select "input[name=?]", "user[hermes_gateway_token]", count: 0
    assert_select "input[name=?]", "user[hermes_hooks_token]", count: 0
  end

  test "direct connection test is retired" do
    sign_in_as(@user)
    post test_connection_settings_path

    assert_response :gone
    assert_equal "direct agent control retired", response.parsed_body["error"]
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
