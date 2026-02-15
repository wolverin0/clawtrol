# frozen_string_literal: true

require "test_helper"

class DiscordConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:18080",
      openclaw_gateway_token: "test-token"
    )
  end

  # ── Auth ──────────────────────────────────────────────────

  test "show requires authentication" do
    get discord_config_path
    assert_response :redirect
  end

  test "update requires authentication" do
    post discord_config_update_path, params: { section: "guilds", values: {} }
    assert_response :redirect
  end

  # ── Gateway not configured ────────────────────────────────

  test "show redirects to settings when gateway not configured" do
    @user.update_columns(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get discord_config_path
    assert_redirected_to settings_path
  end

  # ── Update: section validation ────────────────────────────

  test "update rejects unknown section" do
    sign_in_as(@user)
    post discord_config_update_path, params: { section: "evil", values: {} }, as: :json
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /unknown section/i, json["error"]
  end

  test "update rejects empty section" do
    sign_in_as(@user)
    post discord_config_update_path, params: { section: "", values: {} }, as: :json
    assert_response :unprocessable_entity
  end

  # ── Valid sections accepted ───────────────────────────────

  %w[guilds users reactions actions general].each do |section|
    test "update accepts valid section: #{section}" do
      sign_in_as(@user)
      post discord_config_update_path, params: { section: section, values: {} }, as: :json
      # Should not be "Unknown section" error — might fail at gateway call
      if response.status == 422
        json = JSON.parse(response.body)
        refute_match(/unknown section/i, json["error"].to_s)
      end
    end
  end
end
