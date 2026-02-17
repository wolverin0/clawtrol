# frozen_string_literal: true

require "test_helper"

class TaskDependencyTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task1 = Task.create!(name: "Task 1", board: @board, user: @user)
    @task2 = Task.create!(name: "Task 2", board: @board, user: @user)
    @task3 = Task.create!(name: "Task 3", board: @board, user: @user)
  end

  # --- Validations ---

  test "valid dependency" do
    dep = TaskDependency.new(task: @task1, depends_on: @task2)
    assert dep.valid?, "Expected valid: #{dep.errors.full_messages}"
  end

  test "rejects self-dependency" do
    dep = TaskDependency.new(task: @task1, depends_on: @task1)
    assert_not dep.valid?
    assert_includes dep.errors[:base], "cannot depend on itself"
  end

  test "rejects duplicate dependency" do
    TaskDependency.create!(task: @task1, depends_on: @task2)
    dup = TaskDependency.new(task: @task1, depends_on: @task2)
    assert_not dup.valid?
    assert_includes dup.errors[:task_id], "already has this dependency"
  end

  test "rejects circular dependency (direct)" do
    # Task1 depends on Task2, Task2 depends on Task1
    TaskDependency.create!(task: @task1, depends_on: @task2)
    dep = TaskDependency.new(task: @task2, depends_on: @task1)
    assert_not dep.valid?
    assert_includes dep.errors[:base], "circular dependency"
  end

  test "rejects circular dependency (indirect)" do
    # Task1 -> Task2 -> Task3
    TaskDependency.create!(task: @task1, depends_on: @task2)
    TaskDependency.create!(task: @task2, depends_on: @task3)
    # Task3 -> Task1 would create cycle
    dep = TaskDependency.new(task: @task3, depends_on: @task1)
    assert_not dep.valid?
    assert_includes dep.errors[:base], "circular dependency"
  end

  test "allows valid chain (A->B->C)" do
    # Task1 -> Task2 -> Task3 is valid
    TaskDependency.create!(task: @task1, depends_on: @task2)
    dep = TaskDependency.new(task: @task2, depends_on: @task3)
    assert dep.valid?, "Valid chain should work: #{dep.errors.full_messages}"
  end

  # --- Scopes ---

  test "for_task scope" do
    TaskDependency.create!(task: @task1, depends_on: @task2)
    TaskDependency.create!(task: @task3, depends_on: @task1)

    assert_equal 1, TaskDependency.for_task(@task1).count
    assert_equal 2, TaskDependency.for_task(@task3).count
  end

  test "for_depends_on scope" do
    TaskDependency.create!(task: @task1, depends_on: @task3)
    TaskDependency.create!(task: @task2, depends_on: @task3)

    assert_equal 2, TaskDependency.for_depends_on(@task3).count
  end

  test "recent scope orders by created_at desc" do
    old_dep = TaskDependency.create!(task: @task1, depends_on: @task2)
    old_dep.update_column(:created_at, 1.day.ago)
    new_dep = TaskDependency.create!(task: @task1, depends_on: @task3)

    assert_equal new_dep, TaskDependency.recent.first
  end

  # --- Associations ---

  test "belongs_to task" do
    dep = TaskDependency.create!(task: @task1, depends_on: @task2)
    assert_equal @task1, dep.task
  end

  test "belongs_to depends_on" do
    dep = TaskDependency.create!(task: @task1, depends_on: @task2)
    assert_equal @task2, dep.depends_on
  end

  test "strict_loading_mode is n_plus_one" do
    dep = TaskDependency.new
    assert_equal :n_plus_one, dep.class.strict_loading_mode
  end

  test "allows multiple dependencies from same task" do
    # Task1 can depend on multiple different tasks
    TaskDependency.create!(task: @task1, depends_on: @task2)
    dep2 = TaskDependency.new(task: @task1, depends_on: @task3)
    assert dep2.valid?, "Multiple deps from same task should be valid: #{dep2.errors.full_messages}"
  end

  test "different tasks can depend on same task" do
    # Multiple tasks can depend on the same task
    TaskDependency.create!(task: @task1, depends_on: @task3)
    dep2 = TaskDependency.new(task: @task2, depends_on: @task3)
    assert dep2.valid?, "Multiple tasks depending on same task should be valid"
  end
end
