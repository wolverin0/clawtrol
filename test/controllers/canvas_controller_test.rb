# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class CanvasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
  end

  test "redirects to login when not authenticated" do
    get canvas_path
    assert_response :redirect
  end

  test "redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)

    get canvas_path
    assert_redirected_to settings_path
  end

  test "shows canvas page" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:nodes_status, { "nodes" => [] })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get canvas_path
    end

    assert_response :success
    mock_client.verify
  end

  test "push requires node_id and html_content" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      post canvas_push_path, params: { node_id: "", html_content: "" }
    end

    assert_redirected_to canvas_path
    assert_match(/required/, flash[:alert])
  end

  test "push rejects script tags" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      post canvas_push_path, params: { node_id: "phone", html_content: "<script>alert('xss')</script>" }
    end

    assert_redirected_to canvas_path
    assert_match(/Script tags/, flash[:alert])
  end

  test "push rejects event handlers" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      post canvas_push_path, params: { node_id: "phone", html_content: '<div onload="alert(1)">x</div>' }
    end

    assert_redirected_to canvas_path
    assert_match(/event handlers/, flash[:alert])
  end

  test "push sends valid HTML to gateway" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:canvas_push, { success: true }, node: "phone", html: "<h1>Hello</h1>", width: nil, height: nil)

    OpenclawGatewayClient.stub(:new, mock_client) do
      post canvas_push_path, params: { node_id: "phone", html_content: "<h1>Hello</h1>" }
    end

    assert_redirected_to canvas_path
    assert_match(/successfully/, flash[:notice])
    mock_client.verify
  end

  test "snapshot requires node_id" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      post canvas_snapshot_path, params: { node_id: "" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_match(/required/, response.parsed_body["error"])
  end

  test "hide requires node_id" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      post canvas_hide_path, params: { node_id: "" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_match(/required/, response.parsed_body["error"])
  end

  test "templates endpoint returns JSON array" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    OpenclawGatewayClient.stub(:new, mock_client) do
      get canvas_templates_path, as: :json
    end

    assert_response :success
    templates = response.parsed_body
    assert_kind_of Array, templates
    assert templates.any? { |t| t["id"] == "task_summary" }
    assert templates.any? { |t| t["id"] == "factory_progress" }
    assert templates.any? { |t| t["id"] == "cost_dashboard" }
  end
end
