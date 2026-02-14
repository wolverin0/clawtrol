# frozen_string_literal: true

require "test_helper"

class TokenUsageTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @board = Board.first || Board.create!(name: "Test Board", user: @user)
    @task = Task.create!(name: "Test task", board: @board, user: @user, status: "in_progress")
  end

  # --- Validations ---
  test "valid with required fields" do
    tu = TokenUsage.new(task: @task, model: "opus", input_tokens: 100, output_tokens: 50)
    assert tu.valid?
  end

  test "requires model" do
    tu = TokenUsage.new(task: @task, model: nil, input_tokens: 100, output_tokens: 50)
    assert_not tu.valid?
  end

  test "requires non-negative input_tokens" do
    tu = TokenUsage.new(task: @task, model: "opus", input_tokens: -1, output_tokens: 50)
    assert_not tu.valid?
  end

  test "requires non-negative output_tokens" do
    tu = TokenUsage.new(task: @task, model: "opus", input_tokens: 100, output_tokens: -1)
    assert_not tu.valid?
  end

  # --- Cost calculation ---
  test "calculate_cost for opus" do
    tu = TokenUsage.create!(task: @task, model: "opus", input_tokens: 1_000_000, output_tokens: 1_000_000)
    # opus: $15/M input + $75/M output = $90
    assert_in_delta 90.0, tu.cost, 0.01
  end

  test "calculate_cost for gemini is zero" do
    tu = TokenUsage.create!(task: @task, model: "gemini", input_tokens: 1_000_000, output_tokens: 1_000_000)
    assert_in_delta 0.0, tu.cost, 0.01
  end

  test "calculate_cost for codex" do
    tu = TokenUsage.create!(task: @task, model: "codex", input_tokens: 500_000, output_tokens: 200_000)
    # codex: ($2/M * 0.5) + ($10/M * 0.2) = $1 + $2 = $3
    assert_in_delta 3.0, tu.cost, 0.01
  end

  test "cost recalculated on token change" do
    tu = TokenUsage.create!(task: @task, model: "opus", input_tokens: 0, output_tokens: 0)
    assert_in_delta 0.0, tu.cost, 0.01

    tu.update!(input_tokens: 1_000_000)
    assert_in_delta 15.0, tu.cost, 0.01
  end

  # --- Instance methods ---
  test "total_tokens sums input and output" do
    tu = TokenUsage.new(input_tokens: 100, output_tokens: 50)
    assert_equal 150, tu.total_tokens
  end

  # --- Scopes ---
  test "by_model scope" do
    TokenUsage.create!(task: @task, model: "opus", input_tokens: 100, output_tokens: 50)
    TokenUsage.create!(task: @task, model: "gemini", input_tokens: 200, output_tokens: 100)
    assert_equal 1, TokenUsage.by_model("opus").count
  end

  test "by_date_range scope" do
    TokenUsage.create!(task: @task, model: "opus", input_tokens: 100, output_tokens: 50)
    assert_equal 1, TokenUsage.by_date_range(1.day.ago).count
    assert_equal 0, TokenUsage.by_date_range(1.day.from_now).count
  end

  # --- Class methods ---
  test "total_cost aggregation" do
    TokenUsage.create!(task: @task, model: "opus", input_tokens: 1_000_000, output_tokens: 0)
    TokenUsage.create!(task: @task, model: "codex", input_tokens: 1_000_000, output_tokens: 0)
    total = TokenUsage.where(task: @task).total_cost
    assert_in_delta 17.0, total, 0.01  # opus $15 + codex $2
  end

  test "cost_by_model grouped aggregation" do
    TokenUsage.create!(task: @task, model: "opus", input_tokens: 1_000_000, output_tokens: 0)
    TokenUsage.create!(task: @task, model: "codex", input_tokens: 1_000_000, output_tokens: 0)
    result = TokenUsage.where(task: @task).cost_by_model
    assert_in_delta 15.0, result["opus"], 0.01
    assert_in_delta 2.0, result["codex"], 0.01
  end

  test "record_from_session creates with correct cost" do
    tu = TokenUsage.record_from_session(
      task: @task,
      session_data: { model: "opus", input_tokens: 500_000, output_tokens: 100_000 }
    )
    assert_not_nil tu
    assert_equal "opus", tu.model
    assert_equal 500_000, tu.input_tokens
    assert_equal 100_000, tu.output_tokens
    assert tu.cost > 0
  end

  test "record_from_session normalizes model name" do
    tu = TokenUsage.record_from_session(
      task: @task,
      session_data: { model: "anthropic/claude-opus-4", input_tokens: 100, output_tokens: 50 }
    )
    assert_not_nil tu
    assert_equal "opus", tu.model
  end

  test "record_from_session returns nil for invalid data" do
    assert_nil TokenUsage.record_from_session(task: @task, session_data: "not a hash")
  end

  test "record_from_session returns nil for blank model" do
    assert_nil TokenUsage.record_from_session(task: @task, session_data: { input_tokens: 100, output_tokens: 50 })
  end
end
