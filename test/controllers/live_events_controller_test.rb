# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class LiveEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get live_events_path
    assert_response :redirect
  end

  test "shows live events page" do
    sign_in_as(@user)

    with_multi_stubbed_gateway({
      health: { "version" => "1.0", "uptime" => "2h", "status" => "ok" },
      sessions_list: { "sessions" => [{ "key" => "main", "kind" => "main", "model" => "opus" }] },
      cron_list: { "jobs" => [{ "id" => "test", "name" => "Test Job", "enabled" => true }] },
      channels_status: { "channels" => [{ "name" => "telegram", "connected" => true }] }
    }) do
      get live_events_path
    end

    assert_response :success
    assert_select "h1", /Mission Control/
  end

  test "poll returns JSON" do
    sign_in_as(@user)

    with_multi_stubbed_gateway({
      health: { "version" => "1.0", "status" => "ok" },
      sessions_list: { "sessions" => [] }
    }) do
      get live_events_poll_path, as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("timestamp")
    assert json.key?("gateway")
    assert json.key?("sessions")
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
    follow_redirect! if response.redirect?
  end

  def with_multi_stubbed_gateway(stubs, &block)
    fake_client = Object.new
    stubs.each do |method_name, result|
      fake_client.define_singleton_method(method_name) { result }
    end

    OpenclawGatewayClient.stub(:new, ->(_user, **_) { fake_client }) do
      yield
    end
  end
end
