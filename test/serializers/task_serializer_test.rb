# frozen_string_literal: true

require "test_helper"

class TaskSerializerTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = tasks(:default)
  end

  test "full serialization includes all expected keys" do
    result = TaskSerializer.new(@task).as_json

    assert_kind_of Hash, result
    assert result.key?(:id)
    assert result.key?(:name)
    assert result.key?(:description)
    assert result.key?(:status)
    assert result.key?(:priority)
    assert result.key?(:board_id)
    assert result.key?(:user_id)
    assert result.key?(:tags)
    assert result.key?(:created_at)
    assert result.key?(:updated_at)
    assert result.key?(:openclaw_spawn_model)
    assert result.key?(:pipeline_active)
  end

  test "mini serialization includes only compact keys" do
    result = TaskSerializer.new(@task, mini: true).as_json

    assert_kind_of Hash, result
    assert result.key?(:id)
    assert result.key?(:name)
    assert result.key?(:status)
    assert result.key?(:tags)
    assert result.key?(:priority)
    assert result.key?(:board_id)
    assert result.key?(:completed)
    assert result.key?(:assigned_to_agent)

    # Should NOT include full-only fields
    refute result.key?(:description)
    refute result.key?(:openclaw_spawn_model)
    refute result.key?(:pipeline_active)
    refute result.key?(:execution_plan)
    refute result.key?(:agent_session_id)
  end

  test "timestamps are formatted as ISO8601" do
    result = TaskSerializer.new(@task).as_json

    assert_kind_of String, result[:created_at]
    assert_match(/\d{4}-\d{2}-\d{2}T/, result[:created_at])

    assert_kind_of String, result[:updated_at]
    assert_match(/\d{4}-\d{2}-\d{2}T/, result[:updated_at])
  end

  test "collection serializes multiple tasks" do
    tasks = @board.tasks.limit(3)
    results = TaskSerializer.collection(tasks)

    assert_kind_of Array, results
    results.each { |r| assert_kind_of Hash, r }
  end

  test "collection with mini option" do
    tasks = @board.tasks.limit(3)
    results = TaskSerializer.collection(tasks, mini: true)

    assert_kind_of Array, results
    results.each do |r|
      assert_kind_of Hash, r
      refute r.key?(:description), "Mini serialization should not include description"
    end
  end

  test "mini? returns true when mini option is set" do
    serializer = TaskSerializer.new(@task, mini: true)
    assert serializer.mini?
  end

  test "mini? returns false by default" do
    serializer = TaskSerializer.new(@task)
    refute serializer.mini?
  end

  test "nil timestamps do not raise" do
    # Create a task-like object with nil timestamps
    task = @board.tasks.new(name: "Test nil timestamps", user: @user)
    task.save!

    result = TaskSerializer.new(task).as_json
    assert_kind_of Hash, result
    assert result.key?(:id)
  end

  test "full serialization includes computed fields" do
    result = TaskSerializer.new(@task).as_json

    # openclaw_spawn_model and pipeline_active are computed
    assert result.key?(:openclaw_spawn_model)
    assert result.key?(:pipeline_active)
  end

  test "serialization preserves array fields" do
    @task.update!(tags: ["bug", "urgent"])
    result = TaskSerializer.new(@task).as_json

    assert_equal ["bug", "urgent"], result[:tags]
  end
end
