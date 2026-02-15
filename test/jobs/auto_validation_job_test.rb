# frozen_string_literal: true

require "test_helper"

class AutoValidationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
  end

  test "skips if task not found" do
    assert_nothing_raised do
      AutoValidationJob.perform_now(-1)
    end
  end

  test "skips if task status is not in_review" do
    task = Task.create!(
      name: "Not in review",
      user: @user,
      board: @board,
      status: :inbox,
      description: "Test"
    )

    AutoValidationJob.perform_now(task.id)

    task.reload
    assert_equal "inbox", task.status
  end

  test "skips done tasks" do
    task = Task.create!(
      name: "Already done",
      user: @user,
      board: @board,
      status: :done,
      completed: true,
      description: "Test"
    )

    AutoValidationJob.perform_now(task.id)

    task.reload
    assert_equal "done", task.status
  end

  test "skips in_progress tasks" do
    task = Task.create!(
      name: "In progress",
      user: @user,
      board: @board,
      status: :in_progress,
      description: "Test"
    )

    AutoValidationJob.perform_now(task.id)

    task.reload
    assert_equal "in_progress", task.status
  end

  test "leaves task in_review when no output_files (rule-based returns nil)" do
    task = Task.create!(
      name: "No output files",
      user: @user,
      board: @board,
      status: :in_review,
      description: "Test task without output",
      output_files: []
    )

    AutoValidationJob.perform_now(task.id)

    task.reload
    assert_equal "in_review", task.status
    assert_nil task.validation_command
  end

  test "leaves task in_review when output_files are non-validatable types" do
    task = Task.create!(
      name: "CSS only changes",
      user: @user,
      board: @board,
      status: :in_review,
      description: "Styling changes",
      output_files: ["app/assets/stylesheets/application.css", "app/views/layouts/application.html.erb"]
    )

    AutoValidationJob.perform_now(task.id)

    task.reload
    assert_equal "in_review", task.status
  end

  test "handles exceptions gracefully when output_files is corrupted" do
    task = Task.create!(
      name: "Error handling",
      user: @user,
      board: @board,
      status: :in_review,
      description: "Test",
      output_files: []
    )

    # Corrupt the output_files column to a non-array value
    task.update_columns(output_files: "{invalid}")

    assert_nothing_raised do
      AutoValidationJob.perform_now(task.id)
    end

    # Task should remain in_review (error was caught)
    task.reload
    assert_equal "in_review", task.status
  end
end
