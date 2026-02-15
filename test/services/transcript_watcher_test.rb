# frozen_string_literal: true

require "test_helper"

class TranscriptWatcherTest < ActiveSupport::TestCase
  setup do
    @watcher = TranscriptWatcher.instance
    # Ensure watcher is stopped and offsets are clean for testing
    @watcher.stop
  end

  teardown do
    @watcher.stop
  end

  # --- Singleton behavior ---

  test "is a singleton" do
    assert_equal TranscriptWatcher.instance.object_id, TranscriptWatcher.instance.object_id
  end

  # --- running? state ---

  test "reports not running after stop" do
    assert_not @watcher.running?
  end

  # --- Session ID validation ---

  test "validates session IDs with regex - accepts valid alphanumeric" do
    valid_ids = %w[abc-123 session_key test123 a-b_c]
    valid_ids.each do |id|
      assert id.match?(/\A[a-zA-Z0-9_\-]+\z/), "Expected '#{id}' to be valid"
    end
  end

  test "rejects dangerous session IDs" do
    invalid_ids = ["../etc/passwd", "session;rm", "test<script>", "a b c", ""]
    invalid_ids.each do |id|
      refute id.match?(/\A[a-zA-Z0-9_\-]+\z/), "Expected '#{id}' to be rejected"
    end
  end

  # --- Offset tracking ---

  test "tracks read offsets per session" do
    assert_equal 0, @watcher.send(:current_offset, "test-session")
  end

  test "resets offset for a session" do
    # Manually set an offset via the mutex
    @watcher.instance_variable_get(:@mutex).synchronize do
      @watcher.instance_variable_get(:@file_offsets)["test-session"] = 42
    end
    assert_equal 42, @watcher.send(:current_offset, "test-session")

    @watcher.send(:reset_offset, "test-session")
    assert_equal 0, @watcher.send(:current_offset, "test-session")
  end

  # --- Task lookup ---

  test "find_tasks_for_session returns matching tasks" do
    user = users(:default)
    board = boards(:default)
    task = board.tasks.create!(
      name: "Watcher test task",
      user: user,
      status: :in_progress,
      agent_session_id: "watcher-test-session-123",
      assigned_to_agent: true
    )

    tasks = @watcher.send(:find_tasks_for_session, "watcher-test-session-123")
    assert_includes tasks.map(&:id), task.id
  end

  test "find_tasks_for_session returns empty for unknown session" do
    tasks = @watcher.send(:find_tasks_for_session, "nonexistent-session-xyz")
    assert_empty tasks
  end

  test "find_tasks_for_session only finds in_progress or up_next tasks" do
    user = users(:default)
    board = boards(:default)
    # Use in_review (not done, which requires agent output) to test exclusion
    review_task = board.tasks.create!(
      name: "Review watcher task",
      user: user,
      status: :in_review,
      agent_session_id: "review-session-456"
    )

    tasks = @watcher.send(:find_tasks_for_session, "review-session-456")
    assert_empty tasks
  end

  # --- stop is idempotent ---

  test "stop is safe to call multiple times" do
    assert_nothing_raised do
      @watcher.stop
      @watcher.stop
      @watcher.stop
    end
  end

  # --- Offset cleared on stop ---

  test "stop clears all file offsets when running" do
    # Force running state so stop actually executes
    @watcher.instance_variable_set(:@running, true)
    @watcher.instance_variable_get(:@mutex).synchronize do
      @watcher.instance_variable_get(:@file_offsets)["session-a"] = 10
      @watcher.instance_variable_get(:@file_offsets)["session-b"] = 20
    end

    @watcher.stop

    assert_equal 0, @watcher.send(:current_offset, "session-a")
    assert_equal 0, @watcher.send(:current_offset, "session-b")
    assert_not @watcher.running?
  end
end
