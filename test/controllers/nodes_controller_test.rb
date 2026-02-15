# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class NodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "redirects to login when not authenticated" do
    get nodes_path
    assert_response :redirect
  end

  test "shows empty state when no nodes" do
    sign_in_as(@user)

    with_stubbed_gateway(:nodes_status, { "nodes" => [] }) do
      get nodes_path
    end
    assert_response :success
    assert_select "h3", text: /No Nodes Paired/
  end

  test "shows nodes when gateway returns data" do
    sign_in_as(@user)

    mock_nodes = {
      "nodes" => [
        {
          "id" => "iphone-snake",
          "name" => "Snake's iPhone",
          "status" => "online",
          "platform" => "iOS",
          "version" => "2.1.0",
          "capabilities" => %w[camera location notification],
          "lastSeen" => "2 minutes ago"
        },
        {
          "id" => "linux-server",
          "name" => "homeserver",
          "status" => "offline",
          "platform" => "Linux",
          "capabilities" => ["screen"]
        }
      ]
    }

    with_stubbed_gateway(:nodes_status, mock_nodes) do
      get nodes_path
    end
    assert_response :success
    assert_select "span.text-sm.font-semibold", text: /Snake's iPhone/
    assert_select "span.text-sm.font-semibold", text: /homeserver/
  end

  test "shows error when gateway unreachable" do
    sign_in_as(@user)

    with_stubbed_gateway(:nodes_status, { "nodes" => [], "error" => "Gateway unreachable" }) do
      get nodes_path
    end
    assert_response :success
    assert_select "span.text-red-400", text: /Gateway unreachable/
  end

  test "shows quick action buttons for online nodes" do
    sign_in_as(@user)

    with_stubbed_gateway(:nodes_status, {
      "nodes" => [{
        "id" => "node1",
        "name" => "Test Node",
        "status" => "online",
        "platform" => "iOS"
      }]
    }) do
      get nodes_path
    end
    assert_response :success
    assert_select "button", text: /Notify/
    assert_select "button", text: /Snap/
    assert_select "button", text: /Locate/
  end

  test "hides quick action buttons for offline nodes" do
    sign_in_as(@user)

    with_stubbed_gateway(:nodes_status, {
      "nodes" => [{
        "id" => "node1",
        "name" => "Test Node",
        "status" => "offline",
        "platform" => "Linux"
      }]
    }) do
      get nodes_path
    end
    assert_response :success
    assert_select "button", text: /Notify/, count: 0
  end

  private

  # Stub the gateway client at the class level using OpenclawGatewayClient.stub(:new, ...)
  def with_stubbed_gateway(method_name, result, &block)
    fake_client = Minitest::Mock.new
    fake_client.expect(method_name, result)

    OpenclawGatewayClient.stub(:new, ->(_user, **_) { fake_client }) do
      yield
    end

    fake_client.verify
  end
end
