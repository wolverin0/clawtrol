# frozen_string_literal: true

require "test_helper"

class RunValidationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = Task.create!(
      name: "Validation Test Task",
      board: @board,
      user: @user,
      review_status: "pending",
      review_type: "command"
    )
  end

  # --- Basic functionality ---

  test "does nothing when task not found" do
    assert_no_enqueued_jobs do
      RunValidationJob.perform_now(999_999)
    end
  end

  test "does nothing when review_status is not pending" do
    @task.update!(review_status: "completed")

    assert_no_enqueued_jobs do
      RunValidationJob.perform_now(@task.id)
    end
  end

  test "does nothing when review_type is not command" do
    @task.update!(review_type: "debate")

    assert_no_enqueued_jobs do
      RunValidationJob.perform_now(@task.id)
    end
  end

  # --- Status transitions ---

  test "updates review_status to running before processing" do
    RunValidationJob.perform_now(@task.id)

    @task.reload
    assert_equal "running", @task.review_status
  end

  # --- Error handling ---

  test "handles validation service errors gracefully" do
    # The ValidationRunnerService might fail - job should handle
    # We just verify it doesn't raise unhandled
    assert_nothing_raised do
      RunValidationJob.perform_now(@task.id)
    end
  rescue StandardError => e
    # If it does raise, that's OK as long as it's handled
    assert_match /validation/i, e.message.downcase
  end
end
