# frozen_string_literal: true

require "test_helper"

class TaskExportServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task1 = Task.create!(name: "Export Task 1", board: @board, user: @user, status: :inbox, tags: ["bug"])
    @task2 = Task.create!(name: "Export Task 2", board: @board, user: @user, status: :done, tags: ["feature"])
    @task3 = Task.create!(name: "Archived Task", board: @board, user: @user, status: :archived)
  end

  test "exports all non-archived tasks by default" do
    service = TaskExportService.new(@user)
    tasks = service.tasks

    task_names = tasks.map(&:name)
    assert_includes task_names, "Export Task 1"
    assert_includes task_names, "Export Task 2"
    refute_includes task_names, "Archived Task"
  end

  test "includes archived tasks when requested" do
    service = TaskExportService.new(@user, include_archived: true)
    task_names = service.tasks.map(&:name)
    assert_includes task_names, "Archived Task"
  end

  test "filters by board" do
    other_board = Board.create!(name: "Other", user: @user)
    Task.create!(name: "Other Board Task", board: other_board, user: @user, status: :inbox)

    service = TaskExportService.new(@user, board_id: @board.id)
    task_names = service.tasks.map(&:name)
    assert_includes task_names, "Export Task 1"
    refute_includes task_names, "Other Board Task"
  end

  test "filters by status" do
    service = TaskExportService.new(@user, statuses: ["done"])
    task_names = service.tasks.map(&:name)
    assert_includes task_names, "Export Task 2"
    refute_includes task_names, "Export Task 1"
  end

  test "filters by tag" do
    service = TaskExportService.new(@user, tag: "bug")
    task_names = service.tasks.map(&:name)
    assert_includes task_names, "Export Task 1"
    refute_includes task_names, "Export Task 2"
  end

  test "to_json returns valid JSON with metadata" do
    service = TaskExportService.new(@user)
    json_str = service.to_json
    parsed = JSON.parse(json_str)

    assert parsed.key?("exported_at")
    assert parsed.key?("count")
    assert parsed.key?("tasks")
    assert_kind_of Array, parsed["tasks"]
    assert parsed["count"] >= 2
  end

  test "to_csv returns valid CSV with headers" do
    service = TaskExportService.new(@user)
    csv_str = service.to_csv

    lines = csv_str.lines
    assert lines.length >= 3 # header + at least 2 data rows
    assert_includes lines.first, "name"
    assert_includes lines.first, "status"
    assert_includes lines.first, "board_name"
  end

  test "JSON export includes board_name" do
    service = TaskExportService.new(@user)
    parsed = JSON.parse(service.to_json)
    task_data = parsed["tasks"].find { |t| t["name"] == "Export Task 1" }
    assert_equal @board.name, task_data["board_name"]
  end

  test "handles empty results gracefully" do
    # Filter by a non-existent board to get zero results
    service = TaskExportService.new(@user, board_id: 999999)
    parsed = JSON.parse(service.to_json)
    assert_equal 0, parsed["count"]
    assert_equal [], parsed["tasks"]
  end
end
