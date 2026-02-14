# frozen_string_literal: true

require "test_helper"

class TaskOutcomeServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:default)
    @task = tasks(:default)
    @task.update_columns(status: Task.statuses[:in_progress], run_count: 0)
  end

  def valid_payload
    {
      "version" => "1",
      "run_id" => SecureRandom.uuid,
      "ended_at" => Time.current.iso8601,
      "needs_follow_up" => false,
      "recommended_action" => "in_review",
      "summary" => "Task completed successfully",
      "model_used" => "opus",
      "achieved" => ["Fixed the bug"],
      "evidence" => ["test passes"],
      "remaining" => []
    }
  end

  # --- Validation ---

  test "rejects invalid version" do
    payload = valid_payload.merge("version" => "99")
    result = TaskOutcomeService.call(@task, payload)
    assert_not result.success?
    assert_equal "invalid version", result.error
    assert_equal :unprocessable_entity, result.error_status
  end

  test "rejects invalid run_id" do
    payload = valid_payload.merge("run_id" => "not-a-uuid")
    result = TaskOutcomeService.call(@task, payload)
    assert_not result.success?
    assert_equal "invalid run_id", result.error
  end

  test "rejects invalid recommended_action" do
    payload = valid_payload.merge("recommended_action" => "delete_everything")
    result = TaskOutcomeService.call(@task, payload)
    assert_not result.success?
    assert_equal "invalid recommended_action", result.error
  end

  test "rejects requeue_same_task without next_prompt" do
    payload = valid_payload.merge(
      "needs_follow_up" => true,
      "recommended_action" => "requeue_same_task",
      "next_prompt" => ""
    )
    result = TaskOutcomeService.call(@task, payload)
    assert_not result.success?
    assert_match(/next_prompt required/, result.error)
  end

  # --- Successful processing ---

  test "creates TaskRun on success" do
    payload = valid_payload
    assert_difference("TaskRun.count") do
      result = TaskOutcomeService.call(@task, payload)
      assert result.success?
      assert_not result.idempotent?
    end
  end

  test "sets task to in_review" do
    result = TaskOutcomeService.call(@task, valid_payload)
    assert result.success?
    assert_equal "in_review", @task.reload.status
  end

  test "increments run_count" do
    result = TaskOutcomeService.call(@task, valid_payload)
    assert result.success?
    assert_equal 1, @task.reload.run_count
  end

  test "clears agent_claimed_at" do
    @task.update_columns(agent_claimed_at: Time.current)
    result = TaskOutcomeService.call(@task, valid_payload)
    assert result.success?
    assert_nil @task.reload.agent_claimed_at
  end

  test "stores summary in TaskRun" do
    payload = valid_payload.merge("summary" => "Great work")
    result = TaskOutcomeService.call(@task, payload)
    assert result.success?
    assert_equal "Great work", result.task_run.summary
  end

  test "stores achieved and evidence arrays" do
    result = TaskOutcomeService.call(@task, valid_payload)
    assert result.success?
    assert_equal ["Fixed the bug"], result.task_run.achieved
    assert_equal ["test passes"], result.task_run.evidence
  end

  # --- Idempotency ---

  test "idempotent on duplicate run_id" do
    payload = valid_payload
    result1 = TaskOutcomeService.call(@task, payload)
    assert result1.success?
    assert_not result1.idempotent?

    # Same run_id again
    assert_no_difference("TaskRun.count") do
      result2 = TaskOutcomeService.call(@task, payload)
      assert result2.success?
      assert result2.idempotent?
    end
  end

  # --- Default values ---

  test "defaults ended_at to current time when blank" do
    payload = valid_payload.merge("ended_at" => "")
    result = TaskOutcomeService.call(@task, payload)
    assert result.success?
    assert_not_nil result.task_run.ended_at
  end

  test "defaults recommended_action to in_review" do
    payload = valid_payload.except("recommended_action")
    result = TaskOutcomeService.call(@task, payload)
    assert result.success?
    assert_equal "in_review", result.task_run.recommended_action
  end

  # --- Result struct ---

  test "result responds to success? and idempotent?" do
    result = TaskOutcomeService.call(@task, valid_payload)
    assert_respond_to result, :success?
    assert_respond_to result, :idempotent?
    assert_respond_to result, :task_run
    assert_respond_to result, :task
    assert_respond_to result, :error
  end
end
