# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class WebhookMappingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get webhook_mappings_path
    assert_response :redirect
  end

  test "shows webhook mappings page" do
    sign_in_as(@user)

    mock_config = {
      "config" => {
        "hooks" => {
          "mappings" => [
            { "name" => "GitHub Push", "match" => { "headers" => { "x-github-event" => "push" } }, "action" => "wake" }
          ]
        }
      }
    }

    with_multi_stubbed_gateway({ config_get: mock_config }) do
      get webhook_mappings_path
    end

    assert_response :success
    assert_select "h1", /Webhook Mapping Builder/
  end

  test "save rejects empty mappings" do
    sign_in_as(@user)
    post webhook_mappings_save_path, params: { mappings_json: "" }, as: :json
    assert_response :unprocessable_entity
  end

  test "save rejects invalid JSON" do
    sign_in_as(@user)
    post webhook_mappings_save_path, params: { mappings_json: "not json" }, as: :json
    assert_response :unprocessable_entity
  end

  test "save rejects non-array mappings" do
    sign_in_as(@user)
    post webhook_mappings_save_path, params: { mappings_json: '{"key": "value"}' }, as: :json
    assert_response :unprocessable_entity
  end

  test "save rejects mappings without match" do
    sign_in_as(@user)
    post webhook_mappings_save_path, params: { mappings_json: '[{"action": "wake"}]' }, as: :json
    assert_response :unprocessable_entity
  end

  private

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
