# frozen_string_literal: true

require "test_helper"

class TokenUsageRecorderServiceTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  test "record returns nil when both token counts are zero and no session" do
    result = TokenUsageRecorderService.record(@task, input_tokens: 0, output_tokens: 0)
    assert_nil result
  end

  test "record creates token usage when tokens are provided" do
    assert_difference "TokenUsage.count", 1 do
      TokenUsageRecorderService.record(
        @task,
        input_tokens: 100,
        output_tokens: 200,
        model: "opus"
      )
    end

    usage = TokenUsage.last
    assert_equal 100, usage.input_tokens
    assert_equal 200, usage.output_tokens
    assert_equal "opus", usage.model
    assert_equal @task.id, usage.task_id
  end

  test "record uses task model as fallback" do
    @task.update!(model: "sonnet")

    TokenUsageRecorderService.record(
      @task,
      input_tokens: 50,
      output_tokens: 75
    )

    usage = TokenUsage.last
    assert_equal "sonnet", usage.model
  end

  test "record uses session_key from task" do
    @task.agent_session_key = "test-session-key-123"

    TokenUsageRecorderService.record(
      @task,
      input_tokens: 10,
      output_tokens: 20,
      model: "gemini"
    )

    usage = TokenUsage.last
    assert_equal "test-session-key-123", usage.session_key
  end

  test "extract_from_session returns nil when task has no session_id" do
    @task.agent_session_id = nil
    assert_nil TokenUsageRecorderService.extract_from_session(@task)
  end

  test "extract_from_session returns nil for non-existent transcript" do
    @task.agent_session_id = "nonexistent-session-id"
    assert_nil TokenUsageRecorderService.extract_from_session(@task)
  end
end
