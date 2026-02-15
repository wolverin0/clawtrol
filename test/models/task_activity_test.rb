# frozen_string_literal: true

require "test_helper"

class TaskActivityTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @task = tasks(:one)
  end

  # --- Validations ---

  test "requires action" do
    activity = TaskActivity.new(task: @task, action: nil)
    assert_not activity.valid?
    assert_includes activity.errors[:action], "can't be blank"
  end

  test "valid activity saves" do
    activity = TaskActivity.new(task: @task, action: "created", source: "web")
    assert activity.valid?
  end

  test "rejects invalid action" do
    activity = TaskActivity.new(task: @task, action: "hacked")
    assert_not activity.valid?
    assert_includes activity.errors[:action], "is not included in the list"
  end

  test "rejects invalid source" do
    activity = TaskActivity.new(task: @task, action: "created", source: "evil")
    assert_not activity.valid?
    assert_includes activity.errors[:source], "is not included in the list"
  end

  test "rejects invalid actor_type" do
    activity = TaskActivity.new(task: @task, action: "created", actor_type: "alien")
    assert_not activity.valid?
    assert_includes activity.errors[:actor_type], "is not included in the list"
  end

  test "rejects overly long actor_name" do
    activity = TaskActivity.new(task: @task, action: "created", actor_name: "x" * 201)
    assert_not activity.valid?
    assert activity.errors[:actor_name].any?
  end

  test "rejects overly long note" do
    activity = TaskActivity.new(task: @task, action: "created", note: "x" * 2001)
    assert_not activity.valid?
    assert activity.errors[:note].any?
  end

  test "allows blank source and actor_type" do
    activity = TaskActivity.new(task: @task, action: "created")
    assert activity.valid?
  end

  # --- record_creation ---

  test "record_creation creates web activity" do
    activity = TaskActivity.record_creation(@task)
    assert activity.persisted?
    assert_equal "created", activity.action
    assert_equal "web", activity.source
    assert_equal "user", activity.actor_type
  end

  test "record_creation creates api activity with agent info" do
    activity = TaskActivity.record_creation(@task, source: "api", actor_name: "Otacon", actor_emoji: "📟")
    assert activity.persisted?
    assert_equal "agent", activity.actor_type
    assert_equal "Otacon", activity.actor_name
    assert_equal "📟", activity.actor_emoji
  end

  # --- record_status_change ---

  test "record_status_change tracks old and new status" do
    activity = TaskActivity.record_status_change(@task, old_status: "inbox", new_status: "up_next")
    assert activity.persisted?
    assert_equal "moved", activity.action
    assert_equal "status", activity.field_name
    assert_equal "inbox", activity.old_value
    assert_equal "up_next", activity.new_value
  end

  # --- record_changes ---

  test "record_changes only tracks TRACKED_FIELDS" do
    changes = {
      "name" => ["Old Name", "New Name"],
      "description" => ["old desc", "new desc"],  # not tracked
      "priority" => [0, 2]
    }

    assert_difference "TaskActivity.count", 2 do
      TaskActivity.record_changes(@task, changes)
    end
  end

  test "record_changes skips non-changed tracked fields" do
    changes = { "description" => ["a", "b"] }  # not in TRACKED_FIELDS

    assert_no_difference "TaskActivity.count" do
      TaskActivity.record_changes(@task, changes)
    end
  end

  # --- description ---

  test "description for created from web" do
    activity = TaskActivity.new(action: "created", source: "web")
    assert_equal "Created", activity.description
  end

  test "description for created from api" do
    activity = TaskActivity.new(action: "created", source: "api")
    assert_equal "Created via API", activity.description
  end

  test "description for moved" do
    activity = TaskActivity.new(action: "moved", field_name: "status", old_value: "inbox", new_value: "in_progress")
    assert_equal "Moved from Inbox to In Progress", activity.description
  end

  test "description for updated with old and new values" do
    activity = TaskActivity.new(action: "updated", field_name: "name", old_value: "Old", new_value: "New")
    assert_equal "Changed name from Old to New", activity.description
  end

  test "description for updated with only new value" do
    activity = TaskActivity.new(action: "updated", field_name: "priority", old_value: nil, new_value: "High")
    assert_equal "Set priority to High", activity.description
  end

  test "description for auto_claimed" do
    activity = TaskActivity.new(action: "auto_claimed")
    assert_equal "🤖 Auto-claimed by agent", activity.description
  end

  # --- Scopes ---

  test "recent scope orders by created_at desc" do
    old = task_activities(:created)
    newer = task_activities(:moved)

    # Ensure ordering
    activities = TaskActivity.recent
    assert activities.first.created_at >= activities.last.created_at
  end

  # --- Fixture smoke test ---

  test "fixtures load correctly" do
    assert_equal "created", task_activities(:created).action
    assert_equal "moved", task_activities(:moved).action
    assert_equal "Otacon", task_activities(:moved).actor_name
  end
end
