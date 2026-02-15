# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "unauthenticated request redirects to login" do
    get analytics_path
    assert_response :redirect
  end

  test "renders analytics page when authenticated" do
    sign_in_as(@user)

    Dir.mktmpdir do |dir|
      ENV["OPENCLAW_SESSIONS_DIR"] = dir

      File.write(
        File.join(dir, "abc.jsonl"),
        [
          {
            type: "message",
            timestamp: Time.current.iso8601,
            message: {
              role: "assistant",
              model: "glm-4.7",
              timestamp: Time.current.iso8601,
              usage: {
                input: 10,
                output: 5,
                cacheRead: 0,
                cacheWrite: 0,
                totalTokens: 15,
                cost: { total: 0.1234 }
              }
            }
          }.to_json
        ].join("\n") + "\n"
      )

      get analytics_path(period: "7d")
      assert_response :success
      assert_includes response.body, "COST ANALYTICS"
      assert_includes response.body, "glm-4.7"
    ensure
      ENV.delete("OPENCLAW_SESSIONS_DIR")
    end
  end
end
