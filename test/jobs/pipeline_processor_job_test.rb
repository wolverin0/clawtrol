# frozen_string_literal: true

require "test_helper"

class PipelineProcessorJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
  end

  test "skips if task not found" do
    assert_nothing_raised do
      PipelineProcessorJob.perform_now(-1)
    end
  end

  test "skips if pipeline_enabled is false" do
    task = Task.create!(
      name: "Non-pipeline task",
      user: @user,
      board: @board,
      status: :up_next,
      pipeline_enabled: false,
      pipeline_stage: "unstarted"
    )

    PipelineProcessorJob.perform_now(task.id)

    task.reload
    assert_equal "unstarted", task.pipeline_stage
  end

  test "skips if pipeline_stage is already routed" do
    task = Task.create!(
      name: "Already routed task",
      user: @user,
      board: @board,
      status: :up_next,
      pipeline_enabled: true,
      pipeline_stage: "routed"
    )

    PipelineProcessorJob.perform_now(task.id)

    task.reload
    assert_equal "routed", task.pipeline_stage
  end

  test "skips if pipeline_stage is executing" do
    task = Task.create!(
      name: "Executing task",
      user: @user,
      board: @board,
      status: :up_next,
      pipeline_enabled: true,
      pipeline_stage: "routed",
      compiled_prompt: "test prompt"
    )
    # Bypass validation to set executing directly
    task.update_columns(pipeline_stage: "executing")

    PipelineProcessorJob.perform_now(task.id)

    task.reload
    assert_equal "executing", task.pipeline_stage
  end

  test "skips if pipeline_stage is completed" do
    task = Task.create!(
      name: "Completed task",
      user: @user,
      board: @board,
      status: :up_next,
      pipeline_enabled: true,
      pipeline_stage: "completed"
    )

    PipelineProcessorJob.perform_now(task.id)

    task.reload
    assert_equal "completed", task.pipeline_stage
  end

  test "skips if pipeline_stage is failed" do
    task = Task.create!(
      name: "Failed task",
      user: @user,
      board: @board,
      status: :up_next,
      pipeline_enabled: true,
      pipeline_stage: "failed"
    )

    PipelineProcessorJob.perform_now(task.id)

    task.reload
    assert_equal "failed", task.pipeline_stage
  end

  test "marks task as failed on exception and logs error" do
    task = Task.create!(
      name: "Error task",
      user: @user,
      board: @board,
      status: :up_next,
      pipeline_enabled: true,
      pipeline_stage: "unstarted"
    )

    # Force Pipeline::Orchestrator to raise
    Pipeline::Orchestrator.define_method(:_orig_process, Pipeline::Orchestrator.instance_method(:process_to_completion!))
    Pipeline::Orchestrator.define_method(:process_to_completion!) { raise StandardError, "test error" }

    PipelineProcessorJob.perform_now(task.id)

    task.reload
    assert_equal "failed", task.pipeline_stage
    assert task.pipeline_log.is_a?(Array)
    assert task.pipeline_log.any? { |entry| entry["stage"] == "error" && entry["error"].include?("test error") }
  ensure
    if Pipeline::Orchestrator.method_defined?(:_orig_process)
      Pipeline::Orchestrator.define_method(:process_to_completion!, Pipeline::Orchestrator.instance_method(:_orig_process))
      Pipeline::Orchestrator.remove_method(:_orig_process)
    end
  end
end
