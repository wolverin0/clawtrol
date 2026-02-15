require "test_helper"

class TaskDiffTest < ActiveSupport::TestCase
  # Test parsing and stats methods (unit tests - no DB trigger)

  # === Validations (use build to avoid callbacks) ===
  test "valid with required attributes" do
    task = tasks(:one)
    diff = TaskDiff.new(task: task, file_path: "test.rb", diff_type: "modified")
    assert diff.valid?
  end

  test "requires file_path" do
    task = tasks(:one)
    diff = TaskDiff.new(task: task, diff_type: "modified")
    assert_not diff.valid?
  end

  test "requires diff_type" do
    task = tasks(:one)
    diff = TaskDiff.new(task: task, file_path: "test.rb")
    assert_not diff.valid?
  end

  test "validates diff_type inclusion" do
    task = tasks(:one)
    diff = TaskDiff.new(task: task, file_path: "test.rb", diff_type: "invalid")
    assert_not diff.valid?
  end

  test "file_path length limited to 1000 chars" do
    task = tasks(:one)
    diff = TaskDiff.new(task: task, file_path: "a" * 1001, diff_type: "modified")
    assert_not diff.valid?
  end

  # === Parsing (unit tests - no DB needed) ===
  test "parsed_lines handles nil content" do
    diff = TaskDiff.new(diff_content: nil)
    assert_equal [], diff.parsed_lines
  end

  test "parsed_lines handles empty content" do
    diff = TaskDiff.new(diff_content: "")
    assert_equal [], diff.parsed_lines
  end

  test "parsed_lines extracts additions and deletions" do
    diff = TaskDiff.new(diff_content: "-old\n+new\n context")
    lines = diff.parsed_lines

    assert_equal 3, lines.length
    assert_equal :deletion, lines[0][:type]
    assert_equal "old", lines[0][:content]
    assert_equal :addition, lines[1][:type]
    assert_equal "new", lines[1][:content]
    assert_equal :context, lines[2][:type]
  end

  test "parsed_lines handles hunk headers" do
    diff = TaskDiff.new(diff_content: "@@ -1,5 +1,6 @@ context\n+added\n-old")
    lines = diff.parsed_lines
    assert lines.any? { |l| l[:type] == :hunk }
  end

  # === Stats (unit tests) ===
  test "stats counts additions and deletions" do
    diff = TaskDiff.new(diff_content: "+added1\n+added2\n-deleted1\n context\n+added3")
    stats = diff.stats
    assert_equal 3, stats[:additions]
    assert_equal 1, stats[:deletions]
  end

  test "stats handles nil content" do
    diff = TaskDiff.new(diff_content: nil)
    stats = diff.stats
    assert_equal 0, stats[:additions]
    assert_equal 0, stats[:deletions]
  end
end
