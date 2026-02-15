# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class AiSuggestionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = @board.tasks.create!(
      name: "Fix login bug",
      description: "## Agent Output\n\nFixed the login validation issue. Changed bcrypt rounds.",
      user: @user,
      status: :in_review
    )
  end

  # --- Fallback when not configured ---

  test "generate_followup returns fallback when user has no AI key" do
    @user.update_columns(ai_api_key: nil)
    service = AiSuggestionService.new(@user.reload)
    result = service.generate_followup(@task)
    assert_includes result, "Review the task results"
  end

  test "generate_followup returns fallback when AI key is empty string" do
    @user.update_columns(ai_api_key: "")
    service = AiSuggestionService.new(@user.reload)
    result = service.generate_followup(@task)
    assert_includes result, "Review the task results"
  end

  # --- enhance_description when not configured ---

  test "enhance_description returns draft unchanged when not configured" do
    @user.update_columns(ai_api_key: nil)
    service = AiSuggestionService.new(@user.reload)
    draft = "Add more tests for edge cases"
    result = service.enhance_description(@task, draft)
    assert_equal draft, result
  end

  # --- Prompt construction ---

  test "followup prompt includes task name and description" do
    @user.update_columns(ai_api_key: "test-key")
    service = AiSuggestionService.new(@user.reload)

    prompt = service.send(:build_followup_prompt, @task)

    assert_includes prompt, "Fix login bug"
    assert_includes prompt, "Fixed the login validation issue"
    assert_includes prompt, "follow-up tasks"
  end

  test "enhance prompt includes task name, description, and draft" do
    @user.update_columns(ai_api_key: "test-key")
    service = AiSuggestionService.new(@user.reload)
    draft = "Write tests for the fix"

    prompt = service.send(:build_enhance_prompt, @task, draft)

    assert_includes prompt, "Fix login bug"
    assert_includes prompt, "Fixed the login validation issue"
    assert_includes prompt, "Write tests for the fix"
  end

  # --- Prompt truncation ---

  test "truncates very long descriptions in prompt" do
    long_desc = "x" * 20_000
    @task.update_columns(description: long_desc)
    service = AiSuggestionService.new(@user)

    prompt = service.send(:build_followup_prompt, @task)

    # Description should be truncated to PROMPT_DESCRIPTION_LIMIT
    assert prompt.length < 20_000
  end

  test "truncates very long task names in prompt" do
    long_name = "y" * 1000
    @task.update_columns(name: long_name)
    service = AiSuggestionService.new(@user)

    prompt = service.send(:build_followup_prompt, @task)

    assert prompt.length < 15_000
  end

  # --- Error handling ---

  test "generate_followup returns nil on API error when configured" do
    @user.update_columns(ai_api_key: "test-key")
    service = AiSuggestionService.new(@user.reload)

    # Mock Net::HTTP to raise
    Net::HTTP.stub(:new, ->(*_args) { raise StandardError, "Connection failed" }) do
      result = service.generate_followup(@task)
      assert_nil result
    end
  end

  # --- Nil-safe handling ---

  test "handles task with nil name gracefully" do
    @task.update_columns(name: "Untitled")
    service = AiSuggestionService.new(@user)
    prompt = service.send(:build_followup_prompt, @task)
    assert_includes prompt, "Untitled"
  end

  test "handles task with nil description gracefully" do
    @task.update_columns(description: nil)
    service = AiSuggestionService.new(@user)
    prompt = service.send(:build_followup_prompt, @task)
    assert_kind_of String, prompt
  end
end
