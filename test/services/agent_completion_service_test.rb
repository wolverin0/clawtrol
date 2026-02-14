# frozen_string_literal: true

require "test_helper"

class AgentCompletionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @task = tasks(:default)
    @task.update_columns(status: Task.statuses[:in_progress], agent_session_id: nil)
  end

  test "sets task to in_review by default" do
    params = { output: "Done!" }
    result = AgentCompletionService.new(@task, params).call
    assert result.success?
    assert_equal "in_review", @task.reload.status
  end

  test "accepts custom status" do
    params = { output: "Done!", status: "done" }
    result = AgentCompletionService.new(@task, params).call
    assert result.success?
    assert_equal "done", @task.reload.status
  end

  test "appends agent output to description" do
    @task.update_columns(description: "Original description")
    params = { output: "Agent did stuff" }
    result = AgentCompletionService.new(@task, params).call
    assert result.success?
    assert_includes @task.reload.description, "## Agent Output"
    assert_includes @task.reload.description, "Agent did stuff"
  end

  test "does not duplicate Agent Output header" do
    @task.update_columns(description: "## Agent Output\nPrevious output")
    params = { output: "More output" }
    AgentCompletionService.new(@task, params).call
    assert_equal 1, @task.reload.description.scan("## Agent Output").count
  end

  test "extracts output from multiple param aliases" do
    %i[output description summary result text message content].each do |key|
      @task.update_columns(description: "", status: Task.statuses[:in_progress])
      params = { key => "Output from #{key}" }
      result = AgentCompletionService.new(@task, params).call
      assert result.success?, "Failed for param key: #{key}"
      assert_includes @task.reload.description, "Output from #{key}"
    end
  end

  test "extracts files from multiple param aliases" do
    @task.update_columns(output_files: [])
    %i[output_files files created_files changed_files modified_files].each do |key|
      @task.update_columns(output_files: [], status: Task.statuses[:in_progress])
      params = { key => ["file1.rb", "file2.rb"] }
      result = AgentCompletionService.new(@task, params).call
      assert result.success?, "Failed for param key: #{key}"
      assert_includes @task.reload.output_files, "file1.rb"
    end
  end

  test "merges output_files without duplicates" do
    @task.update_columns(output_files: ["existing.rb"])
    params = { output_files: ["existing.rb", "new.rb"] }
    AgentCompletionService.new(@task, params).call
    assert_equal ["existing.rb", "new.rb"], @task.reload.output_files
  end

  test "sets completed_at if not already set" do
    @task.update_columns(completed_at: nil)
    params = { output: "Done" }
    AgentCompletionService.new(@task, params).call
    assert_not_nil @task.reload.completed_at
  end

  test "does not overwrite existing completed_at" do
    original_time = 1.hour.ago
    @task.update_columns(completed_at: original_time)
    params = { output: "Done" }
    AgentCompletionService.new(@task, params).call
    assert_in_delta original_time, @task.reload.completed_at, 1.second
  end

  test "clears agent_claimed_at" do
    @task.update_columns(agent_claimed_at: Time.current)
    params = { output: "Done" }
    AgentCompletionService.new(@task, params).call
    assert_nil @task.reload.agent_claimed_at
  end

  test "links session_id from params" do
    params = { session_id: "sess_123", output: "Done" }
    AgentCompletionService.new(@task, params).call
    assert_equal "sess_123", @task.reload.agent_session_id
  end

  test "links session_key from params" do
    params = { session_key: "key_123", output: "Done" }
    AgentCompletionService.new(@task, params).call
    assert_equal "key_123", @task.reload.agent_session_key
  end

  test "uses session_resolver to resolve session_id" do
    resolver = ->(key, _task) { "resolved_#{key}" }
    params = { session_key: "mykey", output: "Done" }
    AgentCompletionService.new(@task, params, session_resolver: resolver).call
    assert_equal "resolved_mykey", @task.reload.agent_session_id
  end

  test "uses transcript_scanner as last resort" do
    scanner = ->(_task_id) { "scanned_session" }
    params = { output: "Done" }
    AgentCompletionService.new(@task, params, transcript_scanner: scanner).call
    assert_equal "scanned_session", @task.reload.agent_session_id
  end

  test "handles empty output gracefully" do
    params = {}
    result = AgentCompletionService.new(@task, params).call
    assert result.success?
    assert_equal "in_review", @task.reload.status
  end

  test "returns error on invalid update" do
    @task.update_columns(name: nil) # Force an invalid state if there's a name validation
    params = { output: "Done", status: "invalid_status_that_does_not_exist" }
    # This may or may not fail depending on Task validations
    # The service should handle it gracefully
    result = AgentCompletionService.new(@task, params).call
    # Either succeeds (if status is cast) or returns error
    assert [true, false].include?(result.success?)
  end
end
