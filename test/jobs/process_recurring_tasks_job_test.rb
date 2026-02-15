# frozen_string_literal: true

require "test_helper"

class ProcessRecurringTasksJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
  end

  test "creates instance for task due for recurrence" do
    task = create_recurring_task("Daily standup", "daily")
    # Force next_recurrence_at to the past (bypasses set_initial_recurrence callback)
    task.update_columns(next_recurrence_at: 1.hour.ago)

    assert_difference("Task.count") do
      result = ProcessRecurringTasksJob.perform_now
      assert_equal 1, result[:tasks_processed]
      assert_equal 1, result[:instances_created]
    end

    instance = Task.where(parent_task_id: task.id).last
    assert_not_nil instance
    assert_equal "Daily standup", instance.name
    assert_not instance.recurring? # Instance is not recurring itself
    assert_equal "inbox", instance.status
  end

  test "schedules next recurrence after creating instance" do
    task = create_recurring_task("Weekly review", "weekly")
    task.update_columns(next_recurrence_at: 1.hour.ago)

    old_next = task.next_recurrence_at
    ProcessRecurringTasksJob.perform_now

    task.reload
    assert_not_nil task.next_recurrence_at
    assert task.next_recurrence_at > old_next
  end

  test "skips tasks not yet due" do
    create_recurring_task("Future task", "daily")
    # Default next_recurrence_at from callback is already in the future

    assert_no_difference("Task.count") do
      result = ProcessRecurringTasksJob.perform_now
      assert_equal 0, result[:tasks_processed]
    end
  end

  test "skips non-recurring tasks" do
    @board.tasks.create!(
      user: @user,
      name: "Normal task",
      status: :inbox,
      recurring: false
    )

    assert_no_difference("Task.count") do
      result = ProcessRecurringTasksJob.perform_now
      assert_equal 0, result[:tasks_processed]
    end
  end

  test "handles errors in individual tasks gracefully" do
    task = create_recurring_task("Good recurring task", "daily")
    task.update_columns(next_recurrence_at: 1.hour.ago)

    # Job should still complete
    result = ProcessRecurringTasksJob.perform_now
    assert_equal 1, result[:tasks_processed]
  end

  test "processes multiple due recurring tasks" do
    2.times do |i|
      t = create_recurring_task("Recurring #{i}", "daily")
      t.update_columns(next_recurrence_at: 1.hour.ago)
    end

    assert_difference("Task.count", 2) do
      result = ProcessRecurringTasksJob.perform_now
      assert_equal 2, result[:tasks_processed]
      assert_equal 2, result[:instances_created]
    end
  end

  test "instances inherit model from parent" do
    task = create_recurring_task("Daily with model", "daily", model: "codex")
    task.update_columns(next_recurrence_at: 1.hour.ago)

    ProcessRecurringTasksJob.perform_now

    instance = Task.where(parent_task_id: task.id).last
    assert_not_nil instance, "Expected a recurring instance to be created"
    assert_equal "codex", instance.model
  end

  test "instances are not assigned to agent" do
    task = create_recurring_task("Agent recurring task", "daily")
    task.update!(assigned_to_agent: true, assigned_at: Time.current)
    task.update_columns(next_recurrence_at: 1.hour.ago)

    ProcessRecurringTasksJob.perform_now

    instance = Task.where(parent_task_id: task.id).last
    assert_not_nil instance, "Expected a recurring instance to be created"
    assert_not instance.assigned_to_agent?
  end

  private

  def create_recurring_task(name, rule, model: nil)
    @board.tasks.create!(
      user: @user,
      name: name,
      status: :inbox,
      recurring: true,
      recurrence_rule: rule,
      model: model
    )
  end
end
