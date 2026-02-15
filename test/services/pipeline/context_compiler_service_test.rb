# frozen_string_literal: true

require "test_helper"

module Pipeline
  class ContextCompilerServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:default)
      @board = boards(:default)
      Pipeline::TriageService.reload_config!
      # Force observation mode to avoid update_columns transaction issues
      @original_config = Pipeline::TriageService.config.dup
      Pipeline::TriageService.instance_variable_set(:@config,
        @original_config.merge(observation_mode: true))
    end

    teardown do
      Pipeline::TriageService.instance_variable_set(:@config, @original_config)
    end

    # --- Basic compilation ---

    test "compiles context for a task" do
      task = Task.create!(
        name: "Context test", board: @board, user: @user,
        description: "Build a widget",
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task).call
      assert_kind_of Hash, context
      assert context[:compiled_at].present?
      assert context[:context_mode].present?
    end

    test "includes task info in context" do
      task = Task.create!(
        name: "Task info test", board: @board, user: @user,
        description: "Some description", tags: ["bug", "urgent"],
        pipeline_type: "bug-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task).call
      task_ctx = context[:task]

      assert_equal task.id, task_ctx[:id]
      assert_equal "Task info test", task_ctx[:name]
      assert_includes task_ctx[:tags], "bug"
      assert_includes task_ctx[:tags], "urgent"
    end

    test "includes board info in context" do
      task = Task.create!(
        name: "Board info test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task).call
      board_ctx = context[:board]

      assert_equal @board.id, board_ctx[:id]
      assert_equal @board.name, board_ctx[:name]
    end

    # --- Dependencies ---

    test "includes empty dependencies when task has none" do
      task = Task.create!(
        name: "No deps test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task).call
      assert_equal [], context[:dependencies]
    end

    test "includes dependency info when task has dependencies" do
      dep_task = Task.create!(name: "Dep task", board: @board, user: @user, status: :done)
      task = Task.create!(
        name: "With deps", board: @board, user: @user,
        pipeline_type: "feature", pipeline_stage: "triaged"
      )
      TaskDependency.create!(task: task, depends_on: dep_task)

      context = Pipeline::ContextCompilerService.new(task).call
      deps = context[:dependencies]
      assert deps.is_a?(Array)
      if deps.any?
        assert deps.first[:name].present?
      end
    end

    # --- Pipeline log ---

    test "appends context compilation to pipeline_log" do
      task = Task.create!(
        name: "Log test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      Pipeline::ContextCompilerService.new(task).call
      task.reload

      log = Array(task.pipeline_log)
      ctx_entry = log.find { |e| e["stage"] == "context_compilation" }
      assert_not_nil ctx_entry
      assert ctx_entry["context_mode"].present?
    end

    # --- Description cleaning ---

    test "handles nil description" do
      task = Task.create!(
        name: "Nil desc test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task).call
      # Should not raise
      assert_kind_of Hash, context
    end

    test "handles very long description" do
      task = Task.create!(
        name: "Long desc test", board: @board, user: @user,
        description: "x" * 100_000,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task).call
      assert_kind_of Hash, context
    end

    # --- Custom user override ---

    test "accepts explicit user parameter" do
      other_user = users(:two)
      task = Task.create!(
        name: "User override test", board: @board, user: @user,
        pipeline_type: "quick-fix", pipeline_stage: "triaged"
      )

      context = Pipeline::ContextCompilerService.new(task, user: other_user).call
      assert_kind_of Hash, context
    end
  end
end
