# frozen_string_literal: true

require "test_helper"

class GatewayClientAccessibleTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @user = users(:default)
    sign_in_as(@user)
  end

  # Test via an actual controller that includes the concern
  test "gateway health endpoint returns JSON" do
    get api_v1_gateway_health_path, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    # Should return a hash (either with health data or error)
    assert data.is_a?(Hash)
  end

  test "gateway channels endpoint returns JSON" do
    get api_v1_gateway_channels_path, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert data.is_a?(Hash)
  end

  test "gateway models endpoint returns JSON" do
    get api_v1_gateway_models_path, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert data.is_a?(Hash)
  end

  test "gateway plugins endpoint returns JSON" do
    get api_v1_gateway_plugins_path, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert data.is_a?(Hash)
  end

  test "gateway nodes endpoint returns JSON" do
    get api_v1_gateway_nodes_status_path, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert data.is_a?(Hash)
  end

  test "gateway cost endpoint returns JSON" do
    get api_v1_gateway_cost_path, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert data.is_a?(Hash)
  end
end
