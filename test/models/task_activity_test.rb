# frozen_string_literal: true

require "test_helper"

class TaskActivityTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = tasks(:default)
    @task.update!(board: @board, user: @user)
  end

  # Validations
  test "valid activity can be created" do
    activity = TaskActivity.new(
      task: @task,
      user: @user,
      action: "created",
      source: "web",
      actor_type: "user"
    )
    assert activity.save
  end

  test "action is required" do
    activity = TaskActivity.new(task: @task, user: @user)
    assert_not activity.save
    assert_includes activity.errors[:action], "must be present"
  end

  test "action must be valid" do
    activity = TaskActivity.new(task: @task, user: @user, action: "invalid_action")
    assert_not activity.save
    assert_includes activity.errors[:action], "must be one of"
  end

  test "action accepts all valid actions" do
    TaskActivity::ACTIONS.each do |action|
      activity = TaskActivity.new(task: @task, user: @user, action: action)
      assert activity.save, "Failed for action: #{action}"
    end
  end

  test "source is valid" do
    %w[web api system].each do |source|
      activity = TaskActivity.new(task: @task, user: @user, action: "created", source: source)
      assert activity.save, "Failed for source: #{source}"
    end
  end

  test "source can be blank" do
    activity = TaskActivity.new(task: @task, user: @user, action: "created", source: "")
    assert activity.save
  end

  test "actor_type is valid" do
    %w[user agent system].each do |actor_type|
      activity = TaskActivity.new(task: @task, user: @user, action: "created", actor_type: actor_type)
      assert activity.save, "Failed for actor_type: #{actor_type}"
    end
  end

  test "actor_type can be blank" do
    activity = TaskActivity.new(task: @task, user: @user, action: "created", actor_type: "")
    assert activity.save
  end

  test "actor_name max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "created", actor_name: "a" * 201)
    assert_not activity.save
    assert_includes activity.errors[:actor_name], "is too long"
  end

  test "actor_name accepts max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "created", actor_name: "a" * 200)
    assert activity.save
  end

  test "actor_emoji max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "created", actor_emoji: "a" * 21)
    assert_not activity.save
    assert_includes activity.errors[:actor_emoji], "is too long"
  end

  test "note max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "created", note: "a" * 2001)
    assert_not activity.save
    assert_includes activity.errors[:note], "is too long"
  end

  test "field_name max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "updated", field_name: "a" * 101)
    assert_not activity.save
    assert_includes activity.errors[:field_name], "is too long"
  end

  test "old_value max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "updated", old_value: "a" * 1001)
    assert_not activity.save
    assert_includes activity.errors[:old_value], "is too long"
  end

  test "new_value max length" do
    activity = TaskActivity.new(task: @task, user: @user, action: "updated", new_value: "a" * 1001)
    assert_not activity.save
    assert_includes activity.errors[:new_value], "is too long"
  end

  # Associations
  test "belongs to task" do
    activity = task_activities(:created_activity)
    assert_equal @task, activity.task
  end

  test "belongs to user (optional)" do
    activity = TaskActivity.new(task: @task, action: "created", user: nil)
    assert activity.save
  end

  # Scopes
  test "recent scope orders by created_at desc" do
    older = TaskActivity.create!(task: @task, user: @user, action: "created", created_at: 1.day.ago)
    newer = TaskActivity.create!(task: @task, user: @user, action: "created", created_at: 1.hour.ago)

    assert_equal [newer, older], TaskActivity.recent.to_a
  end

  # Class Methods
  test "record_creation creates activity" do
    assert_difference "TaskActivity.count", 1 do
      TaskActivity.record_creation(@task, source: "web", actor_name: "Test", actor_emoji: "🤖")
    end

    activity = TaskActivity.last
    assert_equal "created", activity.action
    assert_equal "web", activity.source
    assert_equal "user", activity.actor_type
    assert_equal "Test", activity.actor_name
    assert_equal "🤖", activity.actor_emoji
  end

  test "record_creation sets user from task" do
    TaskActivity.record_creation(@task)
    assert_equal @task.user, TaskActivity.last.user
  end

  test "record_creation for api sets actor_type to agent" do
    TaskActivity.record_creation(@task, source: "api")
    assert_equal "agent", TaskActivity.last.actor_type
  end

  test "record_status_change creates activity" do
    assert_difference "TaskActivity.count", 1 do
      TaskActivity.record_status_change(
        @task,
        old_status: "inbox",
        new_status: "in_progress",
        source: "web"
      )
    end

    activity = TaskActivity.last
    assert_equal "moved", activity.action
    assert_equal "status", activity.field_name
    assert_equal "inbox", activity.old_value
    assert_equal "in_progress", activity.new_value
  end

  test "record_status_change uses Current.user" do
    Current.user = @user
    TaskActivity.record_status_change(@task, old_status: "inbox", new_status: "done")
    assert_equal @user, TaskActivity.last.user
  ensure
    Current.user = nil
  end

  test "record_changes creates activity for each changed tracked field" do
    changes = { "name" => ["Old Name", "New Name"], "priority" => [1, 2] }

    assert_difference "TaskActivity.count", 2 do
      TaskActivity.record_changes(@task, changes)
    end

    assert TaskActivity.where(field_name: "name", old_value: "Old Name", new_value: "New Name").exists?
    assert TaskActivity.where(field_name: "priority").exists?
  end

  test "record_changes only tracks TRACKED_FIELDS" do
    changes = { "name" => ["Old", "New"], "untracked_field" => ["a", "b"] }

    assert_difference "TaskActivity.count", 1 do
      TaskActivity.record_changes(@task, changes)
    end

    assert_not TaskActivity.where(field_name: "untracked_field").exists?
  end

  test "record_changes skips fields without changes" do
    changes = { "name" => ["Old", "New"] }

    assert_difference "TaskActivity.count", 1 do
      TaskActivity.record_changes(@task, changes)
    end
  end

  test "format_value handles priority" do
    # Priority 1 = high
    formatted = TaskActivity.send(:format_value, "priority", 1)
    assert_equal "High", formatted
  end

  test "format_value handles date" do
    date = Date.new(2026, 2, 15)
    formatted = TaskActivity.send(:format_value, "due_date", date)
    assert_equal "Feb 15, 2026", formatted
  end

  test "format_value handles string" do
    formatted = TaskActivity.send(:format_value, "name", "Test Task")
    assert_equal "Test Task", formatted
  end

  test "format_value handles nil" do
    assert_nil TaskActivity.send(:format_value, "name", nil)
  end

  # Description
  test "description for created" do
    activity = TaskActivity.new(action: "created", source: "web")
    assert_equal "Created", activity.description
  end

  test "description for created via api" do
    activity = TaskActivity.new(action: "created", source: "api")
    assert_equal "Created via API", activity.description
  end

  test "description for moved" do
    activity = TaskActivity.new(
      action: "moved",
      field_name: "status",
      old_value: "inbox",
      new_value: "in_progress"
    )
    assert_equal "Moved from Inbox to In Progress", activity.description
  end

  test "description for moved with custom status" do
    activity = TaskActivity.new(
      action: "moved",
      field_name: "status",
      old_value: "custom_status",
      new_value: "another_status"
    )
    assert_equal "Moved from Custom status to Another status", activity.description
  end

  test "description for updated sets field" do
    activity = TaskActivity.new(
      action: "updated",
      field_name: "name",
      old_value: nil,
      new_value: "New Name"
    )
    assert_equal "Set name to New Name", activity.description
  end

  test "description for updated removes field" do
    activity = TaskActivity.new(
      action: "updated",
      field_name: "name",
      old_value: "Old Name",
      new_value: nil
    )
    assert_equal "Removed name", activity.description
  end

  test "description for updated changes field" do
    activity = TaskActivity.new(
      action: "updated",
      field_name: "name",
      old_value: "Old Name",
      new_value: "New Name"
    )
    assert_equal "Changed name from Old Name to New Name", activity.description
  end

  test "description for auto_claimed" do
    activity = TaskActivity.new(action: "auto_claimed")
    assert_equal "🤖 Auto-claimed by agent", activity.description
  end

  test "description for unknown action" do
    activity = TaskActivity.new(action: "unknown_action")
    assert_equal "Unknown action", activity.description
  end

  # Integration with Task
  test "task creates activity on creation" do
    task = Task.create!(title: "Test", board: @board, user: @user)
    assert TaskActivity.where(task: task, action: "created").exists?
  end
end
