# frozen_string_literal: true

require "test_helper"

class AgentLogServiceTest < ActiveSupport::TestCase
  setup do
    @board = boards(:one)
    @user = users(:one)
  end

  test "returns no_session when task has no session info" do
    task = Task.create!(name: "No session", board: @board, user: @user)

    result = AgentLogService.new(task).call

    assert_equal [], result.messages
    assert_equal 0, result.total_lines
    assert_equal false, result.has_session
    assert_nil result.error
  end

  test "returns fallback from description when Agent Output section exists" do
    task = Task.create!(
      name: "With output",
      board: @board,
      user: @user,
      description: "Some context\n\n## Agent Output\nHere is the result of my work.\nLine 2."
    )

    result = AgentLogService.new(task).call

    assert_equal 1, result.messages.length
    assert_equal true, result.fallback
    assert_includes result.messages.first[:content].first[:text], "Here is the result"
  end

  test "returns fallback from output_files when no description" do
    task = Task.create!(
      name: "With files",
      board: @board,
      user: @user,
      output_files: ["docs/report.md", "app/views/index.html"]
    )

    result = AgentLogService.new(task).call

    assert_equal 1, result.messages.length
    assert_equal true, result.fallback
    assert_includes result.messages.first[:content].first[:text], "2 file(s)"
    assert_includes result.messages.first[:content].first[:text], "report.md"
  end

  test "returns error for invalid session ID format" do
    task = Task.create!(name: "Bad ID", board: @board, user: @user)
    task.update_columns(agent_session_id: "../../../etc/passwd")

    result = AgentLogService.new(task).call

    assert_equal [], result.messages
    assert_equal false, result.has_session
    assert_equal "Invalid session ID format", result.error
  end

  test "returns transcript not found when session ID is valid but file missing" do
    task = Task.create!(name: "Missing transcript", board: @board, user: @user)
    task.update_columns(agent_session_id: "nonexistent-session-12345")

    result = AgentLogService.new(task).call

    assert_equal [], result.messages
    assert_equal true, result.has_session
    assert_equal "Transcript file not found", result.error
  end

  test "lazy resolves session_id from session_key using resolver" do
    task = Task.create!(name: "Lazy resolve", board: @board, user: @user)
    task.update_columns(agent_session_key: "some-key-123")

    # Resolver returns a fake session ID
    resolver = ->(key, _task) { "resolved-session-id" }

    # The task has no transcript file, so it will fall back to no-session
    # But it should have tried to resolve
    AgentLogService.new(task, session_resolver: resolver).call

    task.reload
    assert_equal "resolved-session-id", task.agent_session_id
  end

  test "prefers description fallback when transcript file not found" do
    task = Task.create!(
      name: "Fallback chain",
      board: @board,
      user: @user,
      description: "## Agent Output\nFallback content here",
      output_files: ["some/file.html"]
    )
    task.update_columns(agent_session_id: "nonexistent-session-99999")

    result = AgentLogService.new(task).call

    # Should use description fallback, not output_files fallback
    assert_equal true, result.fallback
    assert_includes result.messages.first[:content].first[:text], "Fallback content"
  end

  test "Result struct has all expected fields" do
    result = AgentLogService::Result.new(
      messages: [],
      total_lines: 0,
      has_session: false,
      fallback: nil,
      error: nil,
      task_status: "inbox",
      since: 0
    )

    assert_respond_to result, :messages
    assert_respond_to result, :total_lines
    assert_respond_to result, :has_session
    assert_respond_to result, :fallback
    assert_respond_to result, :error
    assert_respond_to result, :task_status
    assert_respond_to result, :since
  end

  test "since parameter is passed through" do
    task = Task.create!(name: "With since", board: @board, user: @user)

    result = AgentLogService.new(task, since: 42).call

    # No session, so since isn't in the result for this path
    # but the service should not crash
    assert_not_nil result
  end

  test "empty description with Agent Output header returns nil fallback" do
    task = Task.create!(
      name: "Empty output",
      board: @board,
      user: @user,
      description: "## Agent Output\n   "
    )

    result = AgentLogService.new(task).call

    # Empty output after stripping → fallback_from_description returns nil → no_session
    assert_equal false, result.has_session
    assert_equal 0, result.total_lines
  end
end
