# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class AgentConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get agent_config_path
    assert_response :redirect
  end

  test "shows agent config page" do
    sign_in_as(@user)

    mock_config = {
      "config" => {
        "defaultModel" => "anthropic/claude-opus-4",
        "agents" => {
          "definitions" => {
            "researcher" => { "model" => "google/gemini-2.5-pro", "workspace" => "/tmp/research" }
          },
          "bindings" => { "telegram:123" => "researcher" }
        },
        "toolProfiles" => { "minimal" => %w[read write] }
      }
    }

    with_multi_stubbed_gateway({ config_get: mock_config, health: { "version" => "1.0" },
                                 agents_list: { "agents" => [] }, channels_status: { "channels" => [] } }) do
      get agent_config_path
    end

    assert_response :success
    assert_select "h1", /Multi-Agent Config/
  end

  test "shows empty state when no agents configured" do
    sign_in_as(@user)

    mock_config = { "config" => { "defaultModel" => "default" } }

    with_multi_stubbed_gateway({ config_get: mock_config, health: {},
                                 agents_list: { "agents" => [] }, channels_status: { "channels" => [] } }) do
      get agent_config_path
    end

    assert_response :success
    assert_select "p", /No named agents configured/
  end

  test "update_agent rejects blank agent_id" do
    sign_in_as(@user)
    patch agent_config_update_agent_path, params: { agent_id: "" }, as: :json
    assert_response :unprocessable_entity
  end

  test "update_agent rejects invalid agent_id format" do
    sign_in_as(@user)
    patch agent_config_update_agent_path, params: { agent_id: "../etc/passwd" }, as: :json
    assert_response :unprocessable_entity
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
