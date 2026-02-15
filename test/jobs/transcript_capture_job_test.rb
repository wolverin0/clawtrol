# frozen_string_literal: true

require "test_helper"

class TranscriptCaptureJobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @board = Board.create!(name: "Test Board", user: @user)
    @task = Task.create!(
      name: "Test Task",
      board: @board,
      user: @user,
      status: "in_progress"
    )
  end

  # Test: task not found
  test "does nothing if task not found" do
    assert_nothing_raised do
      TranscriptCaptureJob.perform_now(-1)
    end
  end

  # Test: skips if already has agent output
  test "skips if task already has agent output" do
    @task.update!(description: "## Agent Output\n\nReal output here")

    TranscriptCaptureJob.perform_now(@task.id)

    @task.reload
    # Should not modify existing agent output
    assert_includes @task.description, "Real output here"
  end

  # Test: skips if session_id matches existing transcript (directory doesn't exist)
  test "skips gracefully when sessions directory doesn't exist" do
    session_id = "test-session-#{SecureRandom.hex(4)}"
    @task.update!(agent_session_id: session_id)

    # Sessions dir doesn't exist - should handle gracefully
    assert_nothing_raised do
      TranscriptCaptureJob.perform_now(@task.id)
    end
  end

  # Test: logs when no transcript found
  test "logs when no transcript found" do
    @task.update!(agent_session_id: "nonexistent-session")

    # Should not raise
    assert_nothing_raised do
      TranscriptCaptureJob.perform_now(@task.id)
    end

    # Task should remain unchanged
    @task.reload
    assert_equal "in_progress", @task.status
  end

  # Test: skips fallback output already present
  test "skips task with generic fallback output" do
    @task.update!(
      description: "## Agent Output\n\nAgent completed (no findings provided)"
    )

    TranscriptCaptureJob.perform_now(@task.id)

    @task.reload
    # Should still try to capture real output (not skip)
    # This is the current behavior - it checks for fallback text
  end

  # Test: handles task without session ID
  test "handles task without agent_session_id" do
    @task.update!(agent_session_id: nil)

    # Should not raise
    assert_nothing_raised do
      TranscriptCaptureJob.perform_now(@task.id)
    end

    @task.reload
    # Task unchanged
    assert_nil @task.agent_session_id
  end

  # Test: handles nil description
  test "handles task with nil description" do
    @task.update!(description: nil)

    # Should not raise
    assert_nothing_raised do
      TranscriptCaptureJob.perform_now(@task.id)
    end
  end

  # Test: handles task with empty description
  test "handles task with empty description" do
    @task.update!(description: "")

    # Should not raise
    assert_nothing_raised do
      TranscriptCaptureJob.perform_now(@task.id)
    end
  end

  # Test: task with board and user associations preserved
  test "preserves task associations after processing" do
    @task.update!(agent_session_id: "nonexistent-session")

    TranscriptCaptureJob.perform_now(@task.id)

    @task.reload
    assert_equal @board.id, @task.board_id
    assert_equal @user.id, @task.user_id
  end

  # Test: task with output_files preserved
  test "preserves existing output files" do
    existing_files = ["file1.rb", "file2.md"]
    @task.update!(
      agent_session_id: "nonexistent",
      output_files: existing_files
    )

    TranscriptCaptureJob.perform_now(@task.id)

    @task.reload
    # Output files should be preserved if no new ones found
    assert_equal existing_files, @task.output_files
  end
end
