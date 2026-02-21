# frozen_string_literal: true

require "test_helper"
require "tmpdir"

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

  test "does not fallback to description or output_files when no session" do
    task = Task.create!(
      name: "No session fallback",
      board: @board,
      user: @user,
      description: "## Agent Output\nThis must not be returned",
      output_files: ["docs/report.md"]
    )

    result = AgentLogService.new(task).call

    assert_equal [], result.messages
    assert_equal false, result.has_session
    assert_nil result.fallback
  end

  test "returns no_session for invalid session ID format" do
    task = Task.create!(name: "Bad ID", board: @board, user: @user)
    task.update_columns(agent_session_id: "../../../etc/passwd")

    result = AgentLogService.new(task).call

    assert_equal [], result.messages
    assert_equal false, result.has_session
    assert_nil result.error
  end

  test "returns no_session when session ID is valid but transcript file missing" do
    task = Task.create!(name: "Missing transcript", board: @board, user: @user)
    task.update_columns(agent_session_id: "nonexistent-session-12345")

    result = AgentLogService.new(task).call

    assert_equal [], result.messages
    assert_equal false, result.has_session
    assert_nil result.error
  end

  test "lazy resolves session_id from session_key using resolver" do
    task = Task.create!(name: "Lazy resolve", board: @board, user: @user)
    task.update_columns(agent_session_key: "some-key-123")

    resolver = ->(_key, _task) { "resolved-session-id" }

    AgentLogService.new(task, session_resolver: resolver).call

    task.reload
    assert_equal "resolved-session-id", task.agent_session_id
  end

  test "returns no_session when mapped transcript does not match task scope" do
    task = Task.create!(name: "Scope mismatch", board: @board, user: @user)
    task.update_columns(agent_session_id: "session-123", agent_session_key: "agent:main:subagent:xyz")

    Dir.mktmpdir do |dir|
      transcript = File.join(dir, "session-123.jsonl")
      File.write(transcript, <<~JSONL)
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"http://192.168.100.186:4001/zerobitch is broken now"}]}}
      JSONL

      TranscriptParser.stub(:transcript_path, transcript) do
        result = AgentLogService.new(task).call

        assert_equal [], result.messages
        assert_equal false, result.has_session
      end
    end
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
end
