# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SessionsExplorerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "redirects to login when not authenticated" do
    get sessions_explorer_path
    assert_response :redirect
  end

  test "shows empty state when no sessions" do
    sign_in_as(@user)

    with_stubbed_gateway(:sessions_list, { "sessions" => [] }) do
      get sessions_explorer_path
    end
    assert_response :success
    assert_select "h3", text: /No Sessions Found/
  end

  test "shows sessions categorized by kind" do
    sign_in_as(@user)

    mock_sessions = {
      "sessions" => [
        {
          "key" => "main-abc123",
          "kind" => "main",
          "model" => "anthropic/claude-opus-4",
          "status" => "active",
          "tokensIn" => 50000,
          "tokensOut" => 12000,
          "compactions" => 2,
          "lastActivity" => "1 minute ago"
        },
        {
          "key" => "cron-def456",
          "kind" => "cron",
          "model" => "openai-codex/gpt-5.3-codex",
          "status" => "active",
          "tokensIn" => 8000,
          "tokensOut" => 3000
        },
        {
          "key" => "sub-ghi789",
          "kind" => "subagent",
          "model" => "google/gemini-2.5-pro",
          "status" => "completed"
        }
      ]
    }

    with_stubbed_gateway(:sessions_list, mock_sessions) do
      get sessions_explorer_path
    end
    assert_response :success

    # Should show category headers
    assert_select "h2", text: /Main/
    assert_select "h2", text: /Cron/
    assert_select "h2", text: /Sub-Agent/
  end

  test "shows correct session count" do
    sign_in_as(@user)

    with_stubbed_gateway(:sessions_list, {
      "sessions" => [
        { "key" => "s1", "kind" => "main", "status" => "active" },
        { "key" => "s2", "kind" => "cron", "status" => "completed" }
      ]
    }) do
      get sessions_explorer_path
    end
    assert_response :success
    assert_select "p", text: /2 sessions \(1 active\)/
  end

  test "links sessions to ClawTrol tasks" do
    sign_in_as(@user)

    # Create a task linked to a session
    board = @user.boards.first || @user.boards.create!(name: "Test Board", position: 0)
    task = @user.tasks.create!(
      name: "Test Task",
      board: board,
      status: :in_progress,
      agent_session_id: "linked-session-key"
    )

    with_stubbed_gateway(:sessions_list, {
      "sessions" => [
        { "key" => "linked-session-key", "kind" => "subagent", "status" => "active", "model" => "opus" }
      ]
    }) do
      get sessions_explorer_path
    end
    assert_response :success
    assert_select "a", text: /Task ##{task.id}/
  end

  test "handles gateway error gracefully" do
    sign_in_as(@user)

    with_stubbed_gateway(:sessions_list, { "sessions" => [], "error" => "Connection refused" }) do
      get sessions_explorer_path
    end
    assert_response :success
    assert_select "span.text-red-400", text: /Connection refused/
  end

  private

  def with_stubbed_gateway(method_name, result, &block)
    fake_client = Minitest::Mock.new
    fake_client.expect(method_name, result)

    OpenclawGatewayClient.stub(:new, ->(_user, **_) { fake_client }) do
      yield
    end

    fake_client.verify
  end
end
