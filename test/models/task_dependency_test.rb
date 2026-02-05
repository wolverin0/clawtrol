require "test_helper"

class TaskDependencyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task1 = @board.tasks.create!(user: @user, name: "Task 1", status: :inbox)
    @task2 = @board.tasks.create!(user: @user, name: "Task 2", status: :inbox)
    @task3 = @board.tasks.create!(user: @user, name: "Task 3", status: :inbox)
  end

  test "can create a dependency between tasks" do
    dependency = TaskDependency.create!(task: @task1, depends_on: @task2)
    assert dependency.persisted?
    assert_includes @task1.dependencies, @task2
    assert_includes @task2.dependents, @task1
  end

  test "task is blocked when dependency is not done" do
    TaskDependency.create!(task: @task1, depends_on: @task2)
    
    assert @task1.blocked?
    assert_includes @task1.blocking_tasks, @task2
    
    # Complete the dependency
    @task2.update!(status: :done)
    
    refute @task1.reload.blocked?
  end

  test "task is not blocked when dependency is done" do
    @task2.update!(status: :done)
    TaskDependency.create!(task: @task1, depends_on: @task2)
    
    refute @task1.blocked?
  end

  test "task is not blocked when dependency is archived" do
    @task2.update!(status: :archived)
    TaskDependency.create!(task: @task1, depends_on: @task2)
    
    refute @task1.blocked?
  end

  test "cannot create self-dependency" do
    dependency = TaskDependency.new(task: @task1, depends_on: @task1)
    
    refute dependency.valid?
    assert_includes dependency.errors[:base], "A task cannot depend on itself"
  end

  test "cannot create duplicate dependency" do
    TaskDependency.create!(task: @task1, depends_on: @task2)
    
    duplicate = TaskDependency.new(task: @task1, depends_on: @task2)
    refute duplicate.valid?
  end

  test "cannot create circular dependency (direct)" do
    TaskDependency.create!(task: @task1, depends_on: @task2)
    
    circular = TaskDependency.new(task: @task2, depends_on: @task1)
    refute circular.valid?
    assert_includes circular.errors[:base], "This dependency would create a circular dependency"
  end

  test "cannot create circular dependency (indirect)" do
    # task1 depends on task2, task2 depends on task3
    TaskDependency.create!(task: @task1, depends_on: @task2)
    TaskDependency.create!(task: @task2, depends_on: @task3)
    
    # task3 depending on task1 would create a cycle
    circular = TaskDependency.new(task: @task3, depends_on: @task1)
    refute circular.valid?
    assert_includes circular.errors[:base], "This dependency would create a circular dependency"
  end

  test "add_dependency! creates dependency" do
    @task1.add_dependency!(@task2)
    
    assert_includes @task1.dependencies, @task2
    assert @task1.blocked?
  end

  test "remove_dependency! removes dependency" do
    @task1.add_dependency!(@task2)
    assert @task1.blocked?
    
    @task1.remove_dependency!(@task2)
    
    refute @task1.reload.blocked?
    assert_empty @task1.dependencies
  end

  test "blocking_tasks returns only incomplete dependencies" do
    @task1.add_dependency!(@task2)
    @task1.add_dependency!(@task3)
    
    # Complete task2
    @task2.update!(status: :done)
    
    blocking = @task1.blocking_tasks
    assert_equal 1, blocking.count
    assert_includes blocking, @task3
    refute_includes blocking, @task2
  end
end
