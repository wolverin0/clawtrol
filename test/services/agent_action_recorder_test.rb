# frozen_string_literal: true

require "test_helper"

class AgentActionRecorderTest < ActiveSupport::TestCase
  def setup
    @user = users(:default)
    @task = tasks(:default)
    @task.update_columns(agent_session_id: nil)
  end

  # --- Error cases ---

  test "returns error when task has no agent session" do
    result = AgentActionRecorder.new(@task).record!
    assert_nil result.recording
    assert_match(/no agent session/i, result.error)
  end

  test "returns error when transcript not found" do
    @task.update_columns(agent_session_id: "nonexistent-session-id")
    result = AgentActionRecorder.new(@task).record!
    assert_nil result.recording
    assert_match(/transcript not found/i, result.error)
  end

  # --- Constants ---

  test "FILE_TOOLS includes Write and Edit" do
    assert_includes AgentActionRecorder::FILE_TOOLS, "Write"
    assert_includes AgentActionRecorder::FILE_TOOLS, "Edit"
    assert_includes AgentActionRecorder::FILE_TOOLS, "write"
    assert_includes AgentActionRecorder::FILE_TOOLS, "edit"
  end

  test "READ_TOOLS includes Read" do
    assert_includes AgentActionRecorder::READ_TOOLS, "Read"
    assert_includes AgentActionRecorder::READ_TOOLS, "read"
  end

  test "EXEC_TOOLS includes exec" do
    assert_includes AgentActionRecorder::EXEC_TOOLS, "exec"
    assert_includes AgentActionRecorder::EXEC_TOOLS, "Exec"
  end

  test "MAX_ACTIONS is reasonable" do
    assert_equal 200, AgentActionRecorder::MAX_ACTIONS
  end

  test "MAX_SUMMARY_SIZE is reasonable" do
    assert_equal 500, AgentActionRecorder::MAX_SUMMARY_SIZE
  end

  # --- summarize_input (via send) ---

  test "summarize_input for Write tool" do
    recorder = AgentActionRecorder.new(@task)
    input = { "file_path" => "/test.rb", "content" => "puts 'hello'" }
    summary = recorder.send(:summarize_input, "Write", input)
    assert_equal "/test.rb", summary["file_path"]
    assert_equal "write", summary["operation"]
    assert_equal "puts 'hello'", summary["content_preview"]
    assert_equal 1, summary["content_lines"]
  end

  test "summarize_input for Edit tool" do
    recorder = AgentActionRecorder.new(@task)
    input = { "path" => "/test.rb", "old_string" => "old", "new_string" => "new" }
    summary = recorder.send(:summarize_input, "Edit", input)
    assert_equal "/test.rb", summary["file_path"]
    assert_equal "edit", summary["operation"]
    assert_equal "old", summary["old_text_preview"]
    assert_equal "new", summary["new_text_preview"]
  end

  test "summarize_input for Read tool" do
    recorder = AgentActionRecorder.new(@task)
    input = { "path" => "/test.rb", "offset" => 10, "limit" => 20 }
    summary = recorder.send(:summarize_input, "Read", input)
    assert_equal "/test.rb", summary["file_path"]
    assert_equal 10, summary["offset"]
    assert_equal 20, summary["limit"]
  end

  test "summarize_input for exec tool" do
    recorder = AgentActionRecorder.new(@task)
    input = { "command" => "ruby -c test.rb", "timeout" => 30, "workdir" => "/app" }
    summary = recorder.send(:summarize_input, "exec", input)
    assert_equal "ruby -c test.rb", summary["command"]
    assert_equal 30, summary["timeout"]
    assert_equal "/app", summary["workdir"]
  end

  test "summarize_input truncates long content" do
    recorder = AgentActionRecorder.new(@task)
    input = { "file_path" => "/test.rb", "content" => "x" * 1000 }
    summary = recorder.send(:summarize_input, "Write", input)
    assert summary["content_preview"].length <= AgentActionRecorder::MAX_SUMMARY_SIZE + 3 # +3 for "..."
  end

  test "summarize_input for unknown tool" do
    recorder = AgentActionRecorder.new(@task)
    input = { "foo" => "bar", "baz" => "qux" }
    summary = recorder.send(:summarize_input, "UnknownTool", input)
    assert_equal "bar", summary["foo"]
    assert_equal "qux", summary["baz"]
  end

  # --- generate_assertions ---

  test "generate_assertions creates file_exists for file writes" do
    recorder = AgentActionRecorder.new(@task)
    actions = [
      { "tool" => "Write", "input_summary" => { "file_path" => "/app/test.rb" } },
      { "tool" => "Edit", "input_summary" => { "file_path" => "/app/other.rb" } }
    ]
    assertions = recorder.send(:generate_assertions, actions)
    file_asserts = assertions.select { |a| a["type"] == "file_exists" }
    assert_equal 2, file_asserts.size
    assert_equal "/app/test.rb", file_asserts[0]["path"]
    assert_equal "/app/other.rb", file_asserts[1]["path"]
  end

  test "generate_assertions deduplicates file paths" do
    recorder = AgentActionRecorder.new(@task)
    actions = [
      { "tool" => "Write", "input_summary" => { "file_path" => "/app/test.rb" } },
      { "tool" => "Edit", "input_summary" => { "file_path" => "/app/test.rb" } }
    ]
    assertions = recorder.send(:generate_assertions, actions)
    file_asserts = assertions.select { |a| a["type"] == "file_exists" }
    assert_equal 1, file_asserts.size
  end

  test "generate_assertions detects test commands" do
    recorder = AgentActionRecorder.new(@task)
    actions = [
      { "tool" => "exec", "input_summary" => { "command" => "bin/rails test test/models/task_test.rb" } }
    ]
    assertions = recorder.send(:generate_assertions, actions)
    test_asserts = assertions.select { |a| a["type"] == "tests_pass" }
    assert_equal 1, test_asserts.size
  end

  test "generate_assertions detects syntax checks" do
    recorder = AgentActionRecorder.new(@task)
    actions = [
      { "tool" => "exec", "input_summary" => { "command" => "ruby -c app/models/task.rb" } }
    ]
    assertions = recorder.send(:generate_assertions, actions)
    syntax_asserts = assertions.select { |a| a["type"] == "syntax_valid" }
    assert_equal 1, syntax_asserts.size
  end

  # --- build_metadata ---

  test "build_metadata includes tool_counts" do
    recorder = AgentActionRecorder.new(@task)
    actions = [
      { "tool" => "Write", "input_summary" => { "file_path" => "/a.rb" } },
      { "tool" => "Write", "input_summary" => { "file_path" => "/b.rb" } },
      { "tool" => "exec", "input_summary" => { "command" => "ls" } }
    ]
    metadata = recorder.send(:build_metadata, actions, "/tmp/transcript.jsonl")
    assert_equal 2, metadata["tool_counts"]["Write"]
    assert_equal 1, metadata["tool_counts"]["exec"]
    assert_equal 3, metadata["total_tool_calls"]
    assert_equal 2, metadata["file_count"]
  end

  # --- Result struct ---

  test "Result has recording and error" do
    result = AgentActionRecorder::Result.new(recording: nil, error: "test")
    assert_nil result.recording
    assert_equal "test", result.error
  end

  # --- generate_test_code ---

  test "generate_test_code produces valid Ruby" do
    recorder = AgentActionRecorder.new(@task)
    actions = [{ "tool" => "Write", "input_summary" => { "file_path" => "/test.rb" } }]
    assertions = [{ "type" => "file_exists", "path" => "/test.rb", "description" => "File should exist" }]
    code = recorder.send(:generate_test_code, actions, assertions)
    assert_match(/frozen_string_literal/, code)
    assert_match(/class Agent/, code)
    assert_match(/test.*file exists/, code)
  end
end
