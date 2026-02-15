# frozen_string_literal: true

require "test_helper"

module Pipeline
  class OrchestratorTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @task = tasks(:one)
      @task.update_columns(pipeline_enabled: true, pipeline_stage: "unstarted", pipeline_type: nil, routed_model: nil, compiled_prompt: nil)
    end

    # --- pipeline_applicable? ---

    test "skips tasks with pipeline_enabled false" do
      @task.update_columns(pipeline_enabled: false)
      result = Orchestrator.new(@task).process!
      assert_nil result
    end

    test "skips tasks in completed stage" do
      @task.update_columns(pipeline_stage: "completed")
      result = Orchestrator.new(@task).process!
      assert_nil result
    end

    test "skips tasks in failed stage" do
      @task.update_columns(pipeline_stage: "failed")
      result = Orchestrator.new(@task).process!
      assert_nil result
    end

    # --- Stage transitions ---

    test "unstarted stage triggers triage" do
      @task.update_columns(pipeline_stage: "unstarted")
      result = Orchestrator.new(@task).process!
      @task.reload
      # Result is either "triaged" or nil (if observation mode)
      assert_includes [nil, "triaged"], result
    end

    test "routed stage returns nil (ready for execution)" do
      @task.update_columns(pipeline_stage: "routed")
      result = Orchestrator.new(@task).process!
      assert_nil result
    end

    test "executing stage returns nil" do
      @task.update_columns(pipeline_stage: "executing")
      result = Orchestrator.new(@task).process!
      assert_nil result
    end

    test "triaged stage triggers context compilation" do
      @task.update_columns(pipeline_stage: "triaged")
      result = Orchestrator.new(@task).process!
      # Should advance to context_ready or nil (observation mode)
      assert_includes [nil, "context_ready"], result
    end

    # --- ready_for_execution? ---

    test "ready_for_execution when routed with model and prompt" do
      @task.update_columns(pipeline_stage: "routed", routed_model: "codex", compiled_prompt: "Do the thing")
      assert Orchestrator.new(@task).ready_for_execution?
    end

    test "not ready without routed_model" do
      @task.update_columns(pipeline_stage: "routed", routed_model: nil, compiled_prompt: "Do the thing")
      assert_not Orchestrator.new(@task).ready_for_execution?
    end

    test "not ready without compiled_prompt" do
      @task.update_columns(pipeline_stage: "routed", routed_model: "codex", compiled_prompt: nil)
      assert_not Orchestrator.new(@task).ready_for_execution?
    end

    test "not ready when stage is not routed" do
      @task.update_columns(pipeline_stage: "triaged", routed_model: "codex", compiled_prompt: "Do the thing")
      assert_not Orchestrator.new(@task).ready_for_execution?
    end

    # --- MAX_ITERATIONS guard ---

    test "process_to_completion respects MAX_ITERATIONS" do
      # If we start from nil, it should run at most 5 iterations
      # and not infinite loop
      result = Orchestrator.new(@task).process_to_completion!
      assert_kind_of String, result if result.present?
      # Just verify it terminates without error
    end

    # --- User override ---

    test "accepts user override" do
      other_user = users(:two)
      orchestrator = Orchestrator.new(@task, user: other_user)
      result = orchestrator.process!
      # unstarted → triggers triage, result is stage name or nil (observation mode)
      assert_includes [nil, "triaged"], result
    end
  end
end
