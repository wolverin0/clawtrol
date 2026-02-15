# frozen_string_literal: true

require "test_helper"

module Pipeline
  class AutoReviewServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @board = boards(:one)
      @task = tasks(:one)
      @task.update_columns(run_count: 1, validation_command: nil, pipeline_type: nil, tags: [])
    end

    # --- Empty output ---

    test "requeues on empty output" do
      result = AutoReviewService.new(@task, findings: "").evaluate
      assert_equal :requeue, result[:decision]
      assert_match(/empty/i, result[:reason])
    end

    test "requeues on whitespace-only output" do
      result = AutoReviewService.new(@task, findings: "   \n  ").evaluate
      assert_equal :requeue, result[:decision]
    end

    # --- Failure markers ---

    test "requeues when output has failure markers without success" do
      result = AutoReviewService.new(@task, findings: "❌ Task failed with error").evaluate
      assert_equal :requeue, result[:decision]
      assert_match(/failure/i, result[:reason])
    end

    test "does not requeue when output has both failure and success markers" do
      result = AutoReviewService.new(@task, findings: "❌ First attempt failed but ✅ fixed it").evaluate
      assert_not_equal :requeue, result[:decision]
    end

    test "requeues on case-insensitive failure markers" do
      result = AutoReviewService.new(@task, findings: "ERROR occurred during build. FAILED to compile.").evaluate
      assert_equal :requeue, result[:decision]
    end

    # --- Run count > 1 ---

    test "goes to in_review when run_count > 1" do
      @task.update_columns(run_count: 2)
      result = AutoReviewService.new(@task, findings: "Some output").evaluate
      assert_equal :in_review, result[:decision]
      assert_match(/retried/i, result[:reason])
    end

    # --- Research/docs tasks ---

    test "auto-approves research task with substantial output" do
      @task.update_columns(tags: ["research"], pipeline_type: nil)
      findings = "A" * 150  # > 100 chars
      result = AutoReviewService.new(@task, findings: findings).evaluate
      assert_equal :done, result[:decision]
      assert_match(/research/i, result[:reason])
    end

    test "auto-approves docs task with substantial output" do
      @task.update_columns(tags: ["docs"])
      findings = "B" * 150
      result = AutoReviewService.new(@task, findings: findings).evaluate
      assert_equal :done, result[:decision]
    end

    test "auto-approves pipeline_type research with substantial output" do
      @task.update_columns(pipeline_type: "research")
      findings = "C" * 150
      result = AutoReviewService.new(@task, findings: findings).evaluate
      assert_equal :done, result[:decision]
    end

    # --- Trivial tasks ---

    test "auto-approves trivial pipeline_type with substantial output" do
      @task.update_columns(pipeline_type: "quick-fix")
      findings = "D" * 150
      result = AutoReviewService.new(@task, findings: findings).evaluate
      assert_equal :done, result[:decision]
      assert_match(/trivial/i, result[:reason])
    end

    test "auto-approves task tagged hotfix with substantial output" do
      @task.update_columns(tags: ["hotfix"])
      findings = "E" * 150
      result = AutoReviewService.new(@task, findings: findings).evaluate
      assert_equal :done, result[:decision]
    end

    # --- Validation command ---

    test "passes when validation command succeeds" do
      @task.update_columns(validation_command: "true")
      result = AutoReviewService.new(@task, findings: "Valid output").evaluate
      assert_equal :done, result[:decision]
      assert_match(/validation passed/i, result[:reason])
    end

    test "requeues when validation command fails" do
      @task.update_columns(validation_command: "false")
      result = AutoReviewService.new(@task, findings: "Some output").evaluate
      assert_equal :requeue, result[:decision]
      assert_match(/validation failed/i, result[:reason])
    end

    # --- Default fallback ---

    test "defaults to in_review for standard tasks" do
      @task.update_columns(pipeline_type: "feature", tags: ["feature"])
      result = AutoReviewService.new(@task, findings: "Standard feature output").evaluate
      assert_equal :in_review, result[:decision]
      assert_match(/human review/i, result[:reason])
    end

    # --- Edge cases ---

    test "handles nil findings gracefully" do
      result = AutoReviewService.new(@task, findings: nil).evaluate
      assert_equal :requeue, result[:decision]
    end

    test "priority order: run_count check comes first" do
      @task.update_columns(run_count: 3, tags: ["research"])
      result = AutoReviewService.new(@task, findings: "A" * 200).evaluate
      assert_equal :in_review, result[:decision]
    end

    test "substantial output threshold is exactly 100" do
      @task.update_columns(tags: ["research"])

      # Exactly 100 chars — not substantial
      result = AutoReviewService.new(@task, findings: "X" * 100).evaluate
      assert_equal :in_review, result[:decision]

      # 101 chars — substantial
      result = AutoReviewService.new(@task, findings: "X" * 101).evaluate
      assert_equal :done, result[:decision]
    end
  end
end
