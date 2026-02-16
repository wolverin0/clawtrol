require "test_helper"

class TaskDiffTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  # === Validations ===
  test "valid with required attributes" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "modified")
    assert diff.valid?
  end

  test "requires file_path" do
    diff = TaskDiff.new(task: @task, diff_type: "modified")
    assert_not diff.valid?
    assert diff.errors[:file_path].any?
  end

  test "requires diff_type" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb")
    assert_not diff.valid?
    assert diff.errors[:diff_type].any?
  end

  test "validates diff_type inclusion" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "invalid")
    assert_not diff.valid?
    assert diff.errors[:diff_type].any?
  end

  test "file_path length limited to 1000 chars" do
    diff = TaskDiff.new(task: @task, file_path: "a" * 1001, diff_type: "modified")
    assert_not diff.valid?
    assert diff.errors[:file_path].any?
  end

  test "file_path uniqueness scoped to task" do
    existing = TaskDiff.create!(task: @task, file_path: "test.rb", diff_type: "modified")
    duplicate = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "added")
    assert_not duplicate.valid?
    assert duplicate.errors[:file_path].any?
  end

  test "diff_content length limited to 500000 chars" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "modified", diff_content: "a" * 500_001)
    assert_not diff.valid?
    assert diff.errors[:diff_content].any?
  end

  test "diff_content allows nil" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "modified", diff_content: nil)
    assert diff.valid?
  end

  test "diff_content allows blank" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "modified", diff_content: "")
    assert diff.valid?
  end

  test "DIFF_TYPES constant contains expected values" do
    assert_equal %w[modified added deleted], TaskDiff::DIFF_TYPES
  end

  # === Parsing (unit tests) ===
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

  test "parsed_lines handles meta lines" do
    diff = TaskDiff.new(diff_content: "diff --git a/test.rb b/test.rb\n--- a/test.rb\n+++ b/test.rb\n-old\n+new")
    lines = diff.parsed_lines
    # Should skip diff/---/+++ headers
    assert lines.all? { |l| l[:type] != :meta || l[:content].start_with?("\\") }
  end

  # === Stats ===
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

  test "stats handles empty content" do
    diff = TaskDiff.new(diff_content: "")
    stats = diff.stats
    assert_equal 0, stats[:additions]
    assert_equal 0, stats[:deletions]
  end

  test "stats handles only context lines" do
    diff = TaskDiff.new(diff_content: " context1\n context2")
    stats = diff.stats
    assert_equal 0, stats[:additions]
    assert_equal 0, stats[:deletions]
  end

  # === unified_diff_string ===
  test "unified_diff_string returns content as-is if already formatted" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_content: "diff --git a/test.rb b/test.rb\n-old\n+new")
    assert diff.unified_diff_string.start_with?("diff --git")
  end

  test "unified_diff_string wraps content with headers if missing" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "modified", diff_content: "-old\n+new")
    result = diff.unified_diff_string
    assert result.start_with?("diff --git")
    assert result.include?("--- a/test.rb")
    assert result.include?("+++ b/test.rb")
  end

  test "unified_diff_string handles added diff_type" do
    diff = TaskDiff.new(task: @task, file_path: "new.rb", diff_type: "added", diff_content: "+new content")
    result = diff.unified_diff_string
    assert result.include?("--- /dev/null")
    assert result.include?("+++ b/new.rb")
  end

  test "unified_diff_string handles deleted diff_type" do
    diff = TaskDiff.new(task: @task, file_path: "old.rb", diff_type: "deleted", diff_content: "-old content")
    result = diff.unified_diff_string
    assert result.include?("--- a/old.rb")
    assert result.include?("+++ /dev/null")
  end

  test "unified_diff_string returns empty string for nil content" do
    diff = TaskDiff.new(task: @task, file_path: "test.rb", diff_type: "modified", diff_content: nil)
    assert_equal "", diff.unified_diff_string
  end

  # === grouped_lines ===
  test "grouped_lines returns empty for nil content" do
    diff = TaskDiff.new(diff_content: nil)
    assert_equal [], diff.grouped_lines
  end

  test "grouped_lines returns empty for empty content" do
    diff = TaskDiff.new(diff_content: "")
    assert_equal [], diff.grouped_lines
  end

  test "grouped_lines groups changes with context" do
    diff = TaskDiff.new(diff_content: " context1\n context2\n-old\n+new\n context3")
    groups = diff.grouped_lines
    # Should have at least one group with changes
    assert groups.any? { |g| g[:type] == :changes }
  end
end
