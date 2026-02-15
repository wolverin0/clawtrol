# frozen_string_literal: true

require "test_helper"

class CronjobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "unauthenticated request redirects to login" do
    get cronjobs_path(format: :json)
    assert_response :redirect
  end

  test "returns cron jobs JSON when authenticated" do
    sign_in_as(@user)

    sample = {
      jobs: [
        {
          id: "job-1",
          agentId: "main",
          name: "heartbeat",
          enabled: true,
          schedule: { kind: "every", everyMs: 60_000, anchorMs: 1 },
          state: { nextRunAtMs: 1_700_000_000_000, lastRunAtMs: 1_699_999_000_000, lastStatus: "ok", lastDurationMs: 1234, consecutiveErrors: 0 },
          sessionTarget: "main",
          wakeMode: "now"
        },
        {
          id: "job-2",
          agentId: "main",
          name: "daily",
          enabled: false,
          schedule: { kind: "cron", expr: "0 1 * * *", tz: "America/Buenos_Aires" },
          state: { nextRunAtMs: 1_700_000_100_000, lastStatus: "error" }
        }
      ]
    }.to_json

    fake_status = Struct.new(:success?, :exitstatus).new(true, 0)

    with_stubbed_capture3([sample, "", fake_status]) do
      get cronjobs_path(format: :json)
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "online", body["status"]
    assert_equal 2, body["count"]
    assert_equal 2, body["jobs"].length
    assert_equal "job-1", body.dig("jobs", 0, "id")
    assert_includes body.dig("jobs", 0, "scheduleText"), "Every"
  end

  test "toggle returns 422 on missing enabled" do
    sign_in_as(@user)
    post toggle_cronjob_path("job-1"), as: :json
    assert_response :unprocessable_entity
  end

  private

  def with_stubbed_capture3(impl)
    original = Open3.method(:capture3)

    Open3.define_singleton_method(:capture3) do |*args|
      impl.respond_to?(:call) ? impl.call(*args) : impl
    end

    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*args| original.call(*args) }
  end
end
