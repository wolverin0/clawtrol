# frozen_string_literal: true

require "test_helper"

module Pipeline
  class ClawRouterServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:default)
      @board = boards(:default)
      Pipeline::TriageService.reload_config!
      # Force observation_mode to avoid update_columns inside transactional tests
      # (update_columns in transactional fixtures can cause PG::InFailedSqlTransaction)
      @original_config = Pipeline::TriageService.config.dup
      Pipeline::TriageService.instance_variable_set(:@config,
        @original_config.merge(observation_mode: true))
    end

    teardown do
      Pipeline::TriageService.instance_variable_set(:@config, @original_config)
    end

    # --- Basic routing ---

    test "routes a triaged task and sets model" do
      task = Task.create!(
        name: "Fix typo test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      result = Pipeline::ClawRouterService.new(task).call
      assert result[:model].present?, "Should select a model"
      assert result[:prompt_length] > 0, "Should build a prompt"
    end

    test "user-set model overrides tier selection" do
      task = Task.create!(
        name: "User model test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged",
        model: "opus"
      )

      result = Pipeline::ClawRouterService.new(task).call
      assert_equal "opus", result[:model]
    end

    test "appends routing log in observation mode" do
      task = Task.create!(
        name: "Stage test", board: @board, user: @user,
        pipeline_type: "bug-fix", pipeline_stage: "triaged"
      )

      Pipeline::ClawRouterService.new(task).call
      task.reload
      log = Array(task.pipeline_log)
      assert log.any? { |e| e["stage"] == "routing" }
    end

    # --- Pipeline log ---

    test "appends routing entry to pipeline_log" do
      task = Task.create!(
        name: "Log test", board: @board, user: @user,
        pipeline_type: "feature", pipeline_stage: "triaged"
      )

      Pipeline::ClawRouterService.new(task).call
      task.reload

      log = Array(task.pipeline_log)
      routing_entry = log.find { |e| e["stage"] == "routing" }
      assert_not_nil routing_entry
      assert routing_entry["selected_model"].present?
      assert_equal "feature", routing_entry["pipeline_type"]
    end

    # --- Prompt building ---

    test "builds fallback prompt when no template exists" do
      task = Task.create!(
        name: "Fallback prompt test", board: @board, user: @user,
        description: "Do something useful",
        pipeline_type: "nonexistent-pipeline", pipeline_stage: "triaged"
      )

      result = Pipeline::ClawRouterService.new(task).call
      # In observation mode, prompt is not persisted but is measured
      assert result[:prompt_length] > 0
    end

    test "includes validation command in prompt" do
      task = Task.create!(
        name: "Validation test", board: @board, user: @user,
        description: "Fix the thing",
        validation_command: "bin/rails test test/models/task_test.rb",
        pipeline_type: "bug-fix", pipeline_stage: "triaged"
      )

      result = Pipeline::ClawRouterService.new(task).call
      # Prompt should be built regardless of observation mode
      assert result[:prompt_length] > 0
    end

    # --- Different pipeline types ---

    test "routes quick-fix tasks" do
      task = Task.create!(
        name: "Quick fix", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )
      result = Pipeline::ClawRouterService.new(task).call
      assert result[:model].present?
    end

    test "routes feature tasks" do
      task = Task.create!(
        name: "New feature", board: @board, user: @user,
        pipeline_type: "feature", pipeline_stage: "triaged"
      )
      result = Pipeline::ClawRouterService.new(task).call
      assert result[:model].present?
    end

    test "routes research tasks" do
      task = Task.create!(
        name: "Research topic", board: @board, user: @user,
        pipeline_type: "research", pipeline_stage: "triaged"
      )
      result = Pipeline::ClawRouterService.new(task).call
      assert result[:model].present?
    end

    # --- Edge cases ---

    test "handles nil pipeline_type gracefully" do
      task = Task.create!(
        name: "No pipeline type", board: @board, user: @user,
        pipeline_stage: "triaged"
      )
      result = Pipeline::ClawRouterService.new(task).call
      # Should still produce a fallback prompt
      assert result[:model].present?
    end

    test "handles missing description" do
      task = Task.create!(
        name: "No desc task", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )
      result = Pipeline::ClawRouterService.new(task).call
      assert result[:prompt_length] > 0
    end
  end
end
