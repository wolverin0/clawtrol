# frozen_string_literal: true

require "test_helper"

class TaskActivityTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
    @user = users(:two)
  end

  # === Validations ===

  test "action is required" do
    activity = TaskActivity.new(task: @task)
    assert_not activity.valid?
    assert_includes activity.errors[:action], "can't be blank"
  end

  test "action must be valid" do
    activity = TaskActivity.new(task: @task, action: "invalid_action")
    assert_not activity.valid?
    assert_includes activity.errors[:action], "is not included in the list"
  end

  test "valid actions are accepted" do
    TaskActivity::ACTIONS.each do |action|
      activity = TaskActivity.new(task: @task, action: action)
      assert activity.valid?, "Action #{action} should be valid"
    end
  end

  test "source must be valid" do
    activity = TaskActivity.new(task: @task, action: "created", source: "invalid")
    assert_not activity.valid?
    assert_includes activity.errors[:source], "is not included in the list"
  end

  test "valid sources are accepted" do
    %w[web api system].each do |source|
      activity = TaskActivity.new(task: @task, action: "created", source: source)
      assert activity.valid?, "Source #{source} should be valid"
    end
  end

  test "source can be blank" do
    activity = TaskActivity.new(task: @task, action: "created", source: "")
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

  test "valid actor_types are accepted" do
    %w[user agent system].each do |type|
      activity = TaskActivity.new(task: @task, action: "created", actor_type: type)
      assert activity.valid?, "Actor type #{type} should be valid"
    end
  end

  test "actor_name maximum length is 200" do
    activity = TaskActivity.new(
      task: @task,
      action: "created",
      actor_name: "a" * 201
    )
    assert_not activity.valid?
    assert_includes activity.errors[:actor_name], "is too long"
  end

  test "actor_emoji maximum length is 20" do
    activity = TaskActivity.new(
      task: @task,
      action: "created",
      actor_emoji: "a" * 21
    )
    assert_not activity.valid?
    assert_includes activity.errors[:actor_emoji], "is too long"
  end

  test "note maximum length is 2000" do
    activity = TaskActivity.new(
      task: @task,
      action: "created",
      note: "a" * 2001
    )
    assert_not activity.valid?
    assert_includes activity.errors[:note], "is too long"
  end

  test "field_name maximum length is 100" do
    activity = TaskActivity.new(
      task: @task,
      action: "updated",
      field_name: "a" * 101
    )
    assert_not activity.valid?
    assert_includes activity.errors[:field_name], "is too long"
  end

  test "old_value maximum length is 1000" do
    activity = TaskActivity.new(
      task: @task,
      action: "updated",
      field_name: "name",
      old_value: "a" * 1001
    )
    assert_not activity.valid?
    assert_includes activity.errors[:old_value], "is too long"
  end

  test "new_value maximum length is 1000" do
    activity = TaskActivity.new(
      task: @task,
      action: "updated",
      field_name: "name",
      new_value: "a" * 1001
    )
    assert_not activity.valid?
    assert_includes activity.errors[:new_value], "is too long"
  end

  # === Associations ===

  test "belongs to task" do
    activity = task_activities(:one)
    assert_equal @task, activity.task
  end

  test "belongs to user (optional)" do
    activity = TaskActivity.create!(task: @task, action: "created")
    assert_nil activity.user

    activity_with_user = TaskActivity.create!(task: @task, action: "created", user: @user)
    assert_equal @user, activity_with_user.user
  end

  # === Scopes ===

  test "recent scope orders by created_at desc" do
    old_activity = TaskActivity.create!(task: @task, action: "created", created_at: 1.day.ago)
    new_activity = TaskActivity.create!(task: @task, action: "created", created_at: 1.hour.ago)

    recent = TaskActivity.recent
    assert_equal new_activity, recent.first
    assert_equal old_activity, recent.last
  end

  # === Class Methods ===

  test "record_creation creates activity with correct fields" do
    activity = TaskActivity.record_creation(
      @task,
      source: "web",
      actor_name: "Test User",
      actor_emoji: "👤",
      note: "Test note"
    )

    assert_equal @task, activity.task
    assert_equal "created", activity.action
    assert_equal "web", activity.source
    assert_equal "user", activity.actor_type
    assert_equal "Test User", activity.actor_name
    assert_equal "👤", activity.actor_emoji
    assert_equal "Test note", activity.note
  end

  test "record_creation sets actor_type to agent for API source" do
    activity = TaskActivity.record_creation(@task, source: "api")
    assert_equal "agent", activity.actor_type
  end

  test "record_status_change records move activity" do
    activity = TaskActivity.record_status_change(
      @task,
      old_status: "inbox",
      new_status: "up_next",
      source: "web",
      actor_name: "Test"
    )

    assert_equal "moved", activity.action
    assert_equal "status", activity.field_name
    assert_equal "inbox", activity.old_value
    assert_equal "up_next", activity.new_value
    assert_equal "user", activity.actor_type
  end

  test "record_changes only tracks specified fields" do
    changes = {
      name: ["Old", "New"],
      priority: [1, 2],
      due_date: [Date.new(2025, 1, 1), Date.new(2025, 2, 1)],
      # This should be ignored
      description: ["Old desc", "New desc"]
    }

    TaskActivity.record_changes(@task, changes)

    # Check tracked fields were created
    assert TaskActivity.exists?(task: @task, field_name: "name")
    assert TaskActivity.exists?(task: @task, field_name: "priority")
    assert TaskActivity.exists?(task: @task, field_name: "due_date")

    # Non-tracked field should not exist
    assert_not TaskActivity.exists?(task: @task, field_name: "description")
  end

  # === Instance Methods ===

  test "description for created action" do
    activity = TaskActivity.new(task: @task, action: "created", source: "web")
    assert_equal "Created", activity.description
  end

  test "description for created via API" do
    activity = TaskActivity.new(task: @task, action: "created", source: "api")
    assert_equal "Created via API", activity.description
  end

  test "description for moved action" do
    activity = TaskActivity.new(
      task: @task,
      action: "moved",
      old_value: "inbox",
      new_value: "up_next"
    )
    assert_equal "Moved from Inbox to Up Next", activity.description
  end

  test "description for updated with old and new value" do
    activity = TaskActivity.new(
      task: @task,
      action: "updated",
      field_name: "name",
      old_value: "Old Name",
      new_value: "New Name"
    )
    assert_equal "Changed name from Old Name to New Name", activity.description
  end

  test "description for updated setting new value" do
    activity = TaskActivity.new(
      task: @task,
      action: "updated",
      field_name: "name",
      old_value: nil,
      new_value: "New Name"
    )
    assert_equal "Set name to New Name", activity.description
  end

  test "description for updated removing value" do
    activity = TaskActivity.new(
      task: @task,
      action: "updated",
      field_name: "name",
      old_value: "Old Name",
      new_value: nil
    )
    assert_equal "Removed name", activity.description
  end

  test "description for auto_claimed" do
    activity = TaskActivity.new(task: @task, action: "auto_claimed")
    assert_equal "🤖 Auto-claimed by agent", activity.description
  end
end
