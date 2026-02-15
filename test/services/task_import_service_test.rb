# frozen_string_literal: true

require "test_helper"

class TaskImportServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @service = TaskImportService.new(@user, @board)
  end

  # --- JSON parsing ---

  test "returns error for invalid JSON" do
    result = @service.import_json("not valid json {{{")
    assert_equal 0, result.imported
    assert_equal 0, result.skipped
    assert_includes result.errors.first, "Invalid JSON"
  end

  test "returns error when no tasks key present" do
    result = @service.import_json('{"something": "else"}')
    assert_equal 0, result.imported
    assert_includes result.errors.first, "No tasks found"
  end

  # --- Basic import ---

  test "imports valid tasks" do
    json = { tasks: [
      { name: "Import Test Alpha", description: "desc1", status: "inbox" },
      { name: "Import Test Beta", status: "up_next", priority: "high" }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 2, result.imported
    assert_equal 0, result.skipped
    assert_empty result.errors
    assert_equal 2, result.tasks.size

    task = result.tasks.find { |t| t.name == "Import Test Beta" }
    assert_equal "up_next", task.status
    assert_equal "high", task.priority
  end

  test "imports tasks with tags array" do
    json = { tasks: [
      { name: "Tagged Import", tags: ["bug", "urgent"] }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert_equal ["bug", "urgent"], result.tasks.first.tags
  end

  # --- Skipping / dedup ---

  test "skips tasks with blank name" do
    json = { tasks: [
      { name: "", description: "no name" },
      { name: nil },
      { name: "Valid Name" }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert_equal 2, result.skipped
    assert_equal 2, result.errors.size
    assert result.errors.all? { |e| e.include?("blank") }
  end

  test "skips duplicate tasks by name in same board" do
    Task.create!(name: "Already Exists", board: @board, user: @user)

    json = { tasks: [
      { name: "Already Exists" },
      { name: "Brand New" }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert_equal 1, result.skipped
    assert result.errors.first.include?("already exists")
  end

  # --- Status normalization ---

  test "normalizes unknown status to inbox" do
    json = { tasks: [
      { name: "Bad Status Task", status: "nonexistent_status" }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert_equal "inbox", result.tasks.first.status
  end

  test "defaults missing status to inbox" do
    json = { tasks: [{ name: "No Status" }] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert_equal "inbox", result.tasks.first.status
  end

  # --- Safety limits ---

  test "rejects import exceeding MAX_IMPORT_TASKS" do
    tasks = (1..501).map { |i| { name: "Task #{i}" } }
    json = { tasks: tasks }.to_json

    result = @service.import_json(json)
    assert_equal 0, result.imported
    assert result.errors.first.include?("Too many tasks")
  end

  # --- Field filtering ---

  test "only imports IMPORTABLE_FIELDS, ignores unknown fields" do
    json = { tasks: [
      {
        name: "Filtered Task",
        description: "safe",
        status: "inbox",
        agent_session_id: "should-be-ignored",
        user_id: 999,
        id: 12345,
        secret_field: "hacker"
      }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    task = result.tasks.first
    assert_equal "Filtered Task", task.name
    assert_equal "safe", task.description
    assert_nil task.agent_session_id
    assert_equal @user.id, task.user_id  # assigned to correct user, not injected
    assert_not_equal 12345, task.id
  end

  # --- Board scoping ---

  test "imported tasks belong to the specified board" do
    other_board = @user.boards.create!(name: "Other Board", color: "blue")
    service = TaskImportService.new(@user, other_board)

    json = { tasks: [{ name: "Board Scoped Import" }] }.to_json
    result = service.import_json(json)
    assert_equal 1, result.imported
    assert_equal other_board.id, result.tasks.first.board_id
  end

  # --- String key tolerance ---

  test "handles string-keyed task data" do
    json = { "tasks" => [
      { "name" => "String Keys Task", "status" => "in_progress" }
    ] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert_equal "in_progress", result.tasks.first.status
  end

  # --- Edge cases ---

  test "handles empty tasks array" do
    result = @service.import_json('{"tasks": []}')
    assert_equal 0, result.imported
    assert_equal 0, result.skipped
    assert_empty result.errors
  end

  test "truncates very long descriptions" do
    long_desc = "x" * 600_000
    json = { tasks: [{ name: "Long Desc", description: long_desc }] }.to_json

    result = @service.import_json(json)
    assert_equal 1, result.imported
    assert result.tasks.first.description.length <= 500_000
  end
end
