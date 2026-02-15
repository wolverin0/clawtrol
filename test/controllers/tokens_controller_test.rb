# frozen_string_literal: true

require "test_helper"

class TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "unauthenticated request redirects to login" do
    get tokens_path(format: :json)
    assert_response :redirect
  end

  test "returns sessions token JSON when authenticated" do
    sign_in_as(@user)

    sample = {
      activeMinutes: 1440,
      count: 1,
      sessions: [
        {
          key: "agent:main:main",
          updatedAt: 1_700_000_000_000,
          sessionId: "abc",
          totalTokens: 420,
          model: "gpt-5.3-codex",
          abortedLastRun: false
        }
      ]
    }.to_json

    fake_status = Struct.new(:success?, :exitstatus).new(true, 0)

    with_stubbed_capture3([sample, "", fake_status]) do
      get tokens_path(format: :json)
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "online", body["status"]
    assert_equal 1, body["count"]
    assert_equal 420, body["totalTokens"]
    assert_equal "abc", body.dig("sessions", 0, "sessionId")
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
