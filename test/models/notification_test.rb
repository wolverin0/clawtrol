# frozen_string_literal: true

require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @task = tasks(:one)
  end

  # --- Validations ---

  test "event_type is required" do
    n = Notification.new(user: @user, message: "test")
    assert_not n.valid?
    assert n.errors[:event_type].any?
  end

  test "event_type must be in EVENT_TYPES" do
    n = Notification.new(user: @user, event_type: "invalid_type", message: "test")
    assert_not n.valid?
    assert n.errors[:event_type].any?
  end

  test "message is required" do
    n = Notification.new(user: @user, event_type: "task_completed")
    assert_not n.valid?
    assert n.errors[:message].any?
  end

  test "valid notification with all required fields" do
    n = Notification.new(user: @user, event_type: "task_completed", message: "Done!")
    assert n.valid?, "Expected valid: #{n.errors.full_messages}"
  end

  # --- EVENT_TYPES constant ---

  test "EVENT_TYPES includes expected types" do
    expected = %w[task_completed task_errored review_passed review_failed agent_claimed
                  validation_passed validation_failed job_progress job_notify job_alert
                  auto_runner auto_runner_error
                  auto_pull_claimed auto_pull_ready auto_pull_spawned auto_pull_error
                  zombie_task zombie_detected runner_lease_expired runner_lease_missing]
    expected.each do |type|
      assert_includes Notification::EVENT_TYPES, type, "Missing EVENT_TYPE: #{type}"
    end
  end

  # --- Instance methods ---

  test "mark_as_read! sets read_at" do
    n = Notification.create!(user: @user, event_type: "task_completed", message: "test")
    assert n.unread?
    n.mark_as_read!
    n.reload
    assert n.read?
    assert n.read_at.present?
  end

  test "mark_as_read! is idempotent" do
    n = Notification.create!(user: @user, event_type: "task_completed", message: "test")
    n.mark_as_read!
    original_read_at = n.read_at
    n.mark_as_read!
    assert_equal original_read_at, n.read_at
  end

  test "read? and unread? are opposites" do
    n = Notification.create!(user: @user, event_type: "task_completed", message: "test")
    assert n.unread?
    assert_not n.read?

    n.mark_as_read!
    assert n.read?
    assert_not n.unread?
  end

  test "icon returns correct emoji for each event type" do
    assert_equal "✅", Notification.new(event_type: "task_completed").icon
    assert_equal "❌", Notification.new(event_type: "task_errored").icon
    assert_equal "🎉", Notification.new(event_type: "review_passed").icon
    assert_equal "⚠️", Notification.new(event_type: "review_failed").icon
    assert_equal "🤖", Notification.new(event_type: "agent_claimed").icon
    assert_equal "🧟", Notification.new(event_type: "zombie_task").icon
    assert_equal "🏷️", Notification.new(event_type: "runner_lease_expired").icon
  end

  test "color_class returns appropriate class for event types" do
    assert_equal "text-status-success", Notification.new(event_type: "task_completed").color_class
    assert_equal "text-status-error", Notification.new(event_type: "task_errored").color_class
    assert_equal "text-accent", Notification.new(event_type: "agent_claimed").color_class
    assert_equal "text-status-warning", Notification.new(event_type: "runner_lease_expired").color_class
  end

  # --- Dedup ---

  test "create_deduped! suppresses identical event_type+task within dedup window" do
    travel_to Time.utc(2026, 2, 9, 12, 0, 0) do
      first = Notification.create_deduped!(user: @user, task: @task, event_type: "auto_pull_error", message: "boom")
      assert first.present?

      second = Notification.create_deduped!(user: @user, task: @task, event_type: "auto_pull_error", message: "boom again")
      assert_nil second

      assert_equal 1, Notification.where(user: @user, task: @task, event_type: "auto_pull_error").where("created_at >= ?", 10.minutes.ago).count
    end
  end

  test "create_deduped! allows after dedup window" do
    travel_to Time.utc(2026, 2, 9, 12, 0, 0) do
      first = Notification.create_deduped!(user: @user, task: @task, event_type: "task_completed", message: "done1")
      assert first.present?
    end

    travel_to Time.utc(2026, 2, 9, 12, 10, 0) do
      second = Notification.create_deduped!(user: @user, task: @task, event_type: "task_completed", message: "done2")
      assert second.present?
    end
  end

  test "create_deduped! returns nil for nil user" do
    result = Notification.create_deduped!(user: nil, event_type: "task_completed", message: "test")
    assert_nil result
  end

  test "create_deduped! dedupes by event_id within ttl" do
    travel_to Time.utc(2026, 2, 9, 12, 0, 0) do
      first = Notification.create_deduped!(
        user: @user,
        task: @task,
        event_type: "job_notify",
        message: "job done",
        event_id: "evt-123",
        ttl: 30.minutes
      )
      assert first.present?

      # Debug: check what notifications exist before creating second
      puts "DEBUG: Before second create, notifications with evt-123: #{Notification.where(event_id: 'evt-123').count}"

      second = Notification.create_deduped!(
        user: @user,
        task: @task,
        event_type: "job_notify",
        message: "job done again",
        event_id: "evt-123",
        ttl: 30.minutes
      )
      assert_nil second
    end

    travel_to Time.utc(2026, 2, 9, 12, 31, 0) do
      third = Notification.create_deduped!(
        user: @user,
        task: @task,
        event_type: "job_notify",
        message: "job done later",
        event_id: "evt-123",
        ttl: 30.minutes
      )
      assert third.present?
    end
  end

  # --- Scopes ---

  test "unread scope returns only unread notifications" do
    Notification.where(user: @user).delete_all
    unread = Notification.create!(user: @user, event_type: "task_completed", message: "unread")
    read = Notification.create!(user: @user, event_type: "task_errored", message: "read", read_at: Time.current)

    assert_includes Notification.unread, unread
    assert_not_includes Notification.unread, read
  end

  test "read scope returns only read notifications" do
    Notification.where(user: @user).delete_all
    read = Notification.create!(user: @user, event_type: "task_completed", message: "read", read_at: Time.current)
    unread = Notification.create!(user: @user, event_type: "task_errored", message: "unread")

    assert_includes Notification.read, read
    assert_not_includes Notification.read, unread
  end

  # --- Cap ---

  test "cap purges oldest notifications beyond CAP_PER_USER" do
    Notification.where(user: @user).delete_all

    (Notification::CAP_PER_USER + 10).times do |i|
      Notification.create!(user: @user, event_type: "auto_runner", message: "n#{i}")
    end

    assert_equal Notification::CAP_PER_USER, Notification.where(user: @user).count
  end

  # --- Class methods ---

  test "create_for_error creates notification with error message" do
    Notification.where(user: @task.user, task: @task, event_type: "task_errored").delete_all
    Notification.create_for_error(@task, "timeout")
    n = Notification.where(user: @task.user, task: @task, event_type: "task_errored").last
    assert n.present?
    assert_includes n.message, "error"
  end

  test "create_for_review creates notification for passed review" do
    Notification.where(user: @task.user, task: @task, event_type: "review_passed").delete_all
    Notification.create_for_review(@task, passed: true)
    n = Notification.where(user: @task.user, task: @task, event_type: "review_passed").last
    assert n.present?
    assert_includes n.message, "passed"
  end

  test "create_for_review creates notification for failed review" do
    Notification.where(user: @task.user, task: @task, event_type: "review_failed").delete_all
    Notification.create_for_review(@task, passed: false)
    n = Notification.where(user: @task.user, task: @task, event_type: "review_failed").last
    assert n.present?
    assert_includes n.message, "failed"
  end
end
