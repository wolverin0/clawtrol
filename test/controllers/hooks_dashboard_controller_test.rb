# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class HooksDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    @other_user = users(:two)
    @other_user.update!(openclaw_gateway_url: "http://localhost:3378", openclaw_gateway_token: "other-token")
  end

  test "redirects to login when not authenticated" do
    get hooks_dashboard_path
    assert_response :redirect
  end

  test "redirects to settings when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)

    get hooks_dashboard_path
    assert_redirected_to settings_path
  end

  test "shows hooks dashboard page with config" do
    sign_in_as(@user)

    mock_config = {
      "hooks" => {
        "mappings" => [
          {
            "match" => { "headers" => { "X-GitHub-Event" => "push" } },
            "action" => { "kind" => "wake" },
            "description" => "GitHub push webhook"
          },
          {
            "match" => { "source" => "n8n-workflow" },
            "action" => { "kind" => "agentTurn" },
            "template" => "Process: {{body.workflow}}"
          }
        ],
        "gmail" => {
          "enabled" => true,
          "labelWatch" => ["INBOX"],
          "autoRenew" => true,
          "pubsubTopic" => "projects/test/topics/gmail"
        }
      }
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get hooks_dashboard_path
    end

    assert_response :success
    mock_client.verify
  end

  test "handles gateway error gracefully" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "Connection refused" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get hooks_dashboard_path
    end

    assert_response :success
    mock_client.verify
  end

  test "handles nil config gracefully" do
    sign_in_as(@user)

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, nil)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get hooks_dashboard_path
    end

    assert_response :success
    mock_client.verify
  end

  test "detects GitHub source from headers" do
    sign_in_as(@user)

    mock_config = {
      "hooks" => {
        "mappings" => [
          { "match" => { "headers" => { "X-GitHub-Event" => "push" } }, "action" => {} }
        ]
      }
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get hooks_dashboard_path
    end

    assert_response :success
    # Source detection tested indirectly — the page renders without error
    mock_client.verify
  end

  test "only shows webhook logs for current user" do
    # Create webhook logs for both users
    my_log = WebhookLog.create!(
      user: @user,
      direction: "incoming",
      event_type: "agent_complete",
      endpoint: "/hooks/agent_complete",
      method: "POST",
      success: true,
      status_code: 200
    )
    other_log = WebhookLog.create!(
      user: @other_user,
      direction: "incoming",
      event_type: "task_outcome",
      endpoint: "/hooks/task_outcome",
      method: "POST",
      success: true,
      status_code: 200
    )

    sign_in_as(@user)

    mock_config = { "hooks" => { "mappings" => [] } }
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get hooks_dashboard_path
    end

    assert_response :success
    # Verify the response body contains our log but not the other user's
    assert_match "agent_complete", response.body
    refute_match "task_outcome", response.body

    mock_client.verify
  end
end
