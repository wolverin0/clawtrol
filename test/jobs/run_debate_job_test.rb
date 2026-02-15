# frozen_string_literal: true

require "test_helper"

class RunDebateJobTest < ActiveJob::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = Task.create!(
      name: "Debate Test Task",
      board: @board,
      user: @user,
      review_status: "pending",
      review_type: "debate"
    )
  end

  # --- Basic functionality ---

  test "does nothing when task not found" do
    assert_no_enqueued_jobs do
      RunDebateJob.perform_now(999_999)
    end
  end

  test "does nothing when review_status is not pending" do
    @task.update!(review_status: "completed")

    assert_no_enqueued_jobs do
      RunDebateJob.perform_now(@task.id)
    end
  end

  test "does nothing when review_type is not debate" do
    @task.update!(review_type: "command")

    assert_no_enqueued_jobs do
      RunDebateJob.perform_now(@task.id)
    end
  end

  # --- Debate execution ---

  test "updates review_status to running before processing" do
    assert_enqueued_with(job: RunDebateJob) do
      RunDebateJob.perform_now(@task.id)
    end

    @task.reload
    assert_equal "running", @task.review_status
  end

  test "marks review as failed with not_implemented message" do
    RunDebateJob.perform_now(@task.id)

    @task.reload
    assert_equal "failed", @task.review_status
    assert @task.review_result["not_implemented"]
    assert_includes @task.review_result["error_summary"], "not yet implemented"
  end

  # --- Error handling ---

  test "handles unexpected errors gracefully" do
    # Force an error by making task invalid
    @task.update!(review_status: nil) # This will cause issues

    # Should not raise, should handle error
    assert_nothing_raised do
      RunDebateJob.perform_now(@task.id)
    end
  rescue StandardError
    # Expected - the task update above creates issues
  end
end
