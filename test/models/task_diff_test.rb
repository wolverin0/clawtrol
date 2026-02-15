require "test_helper"

class TaskDiffTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  SAMPLE_DIFF = <<~DIFF
    @@ -1,4 +1,5 @@
     class Task
    +  validates :name, presence: true
       belongs_to :board
    -  belongs_to :user
    +  belongs_to :user, optional: true
     end
  DIFF

  # --- Validations ---

  test "valid task_diff" do
    td = TaskDiff.new(task: @task, file_path: "app/models/task.rb", diff_type: "modified")
    assert td.valid?, "Expected valid: #{td.errors.full_messages}"
  end

  test "file_path is required" do
    td = TaskDiff.new(task: @task, diff_type: "modified")
    assert_not td.valid?
    assert td.errors[:file_path].any?
  end

  test "file_path must be unique per task" do
    TaskDiff.create!(task: @task, file_path: "app/unique_file.rb", diff_type: "modified")
    dup = TaskDiff.new(task: @task, file_path: "app/unique_file.rb", diff_type: "modified")
    assert_not dup.valid?
    assert_includes dup.errors[:file_path], "has already been taken"
  end

  test "diff_type must be modified, added, or deleted" do
    %w[modified added deleted].each do |type|
      td = TaskDiff.new(task: @task, file_path: "file_#{type}.rb", diff_type: type)
      assert td.valid?, "Expected diff_type '#{type}' to be valid"
    end
  end

  test "diff_type rejects invalid values" do
    td = TaskDiff.new(task: @task, file_path: "file.rb", diff_type: "renamed")
    assert_not td.valid?
    assert td.errors[:diff_type].any?
  end

  # --- parsed_lines ---

  test "parsed_lines returns empty array for blank diff_content" do
    td = TaskDiff.new(diff_content: nil)
    assert_equal [], td.parsed_lines
  end

  test "parsed_lines parses hunk headers" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    lines = td.parsed_lines
    hunk = lines.find { |l| l[:type] == :hunk }
    assert hunk.present?
    assert_includes hunk[:content], "@@"
  end

  test "parsed_lines identifies additions" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    lines = td.parsed_lines
    additions = lines.select { |l| l[:type] == :addition }
    assert additions.length >= 2
    assert additions.any? { |a| a[:content].include?("validates") }
  end

  test "parsed_lines identifies deletions" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    lines = td.parsed_lines
    deletions = lines.select { |l| l[:type] == :deletion }
    assert deletions.length >= 1
    assert deletions.any? { |d| d[:content].include?("belongs_to :user") }
  end

  test "parsed_lines identifies context lines" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    lines = td.parsed_lines
    context = lines.select { |l| l[:type] == :context }
    assert context.length >= 2
  end

  test "parsed_lines tracks line numbers" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    lines = td.parsed_lines
    first_context = lines.find { |l| l[:type] == :context }
    assert first_context[:old_num].present?
    assert first_context[:new_num].present?
  end

  # --- stats ---

  test "stats counts additions and deletions" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    s = td.stats
    assert s[:additions] >= 2
    assert s[:deletions] >= 1
  end

  test "stats returns zeros for blank diff" do
    td = TaskDiff.new(diff_content: nil)
    s = td.stats
    assert_equal 0, s[:additions]
    assert_equal 0, s[:deletions]
  end

  # --- unified_diff_string ---

  test "unified_diff_string returns empty string for blank diff" do
    td = TaskDiff.new(diff_content: nil)
    assert_equal "", td.unified_diff_string
  end

  test "unified_diff_string wraps raw diff with headers" do
    td = TaskDiff.new(file_path: "app/models/task.rb", diff_type: "modified", diff_content: SAMPLE_DIFF)
    result = td.unified_diff_string
    assert result.start_with?("diff --git")
    assert_includes result, "--- a/app/models/task.rb"
    assert_includes result, "+++ b/app/models/task.rb"
  end

  test "unified_diff_string for added file uses /dev/null as source" do
    td = TaskDiff.new(file_path: "new_file.rb", diff_type: "added", diff_content: "@@ -0,0 +1 @@\n+new content")
    result = td.unified_diff_string
    assert_includes result, "--- /dev/null"
  end

  test "unified_diff_string for deleted file uses /dev/null as target" do
    td = TaskDiff.new(file_path: "old_file.rb", diff_type: "deleted", diff_content: "@@ -1 +0,0 @@\n-old content")
    result = td.unified_diff_string
    assert_includes result, "+++ /dev/null"
  end

  test "unified_diff_string preserves existing headers" do
    content = "diff --git a/f.rb b/f.rb\n--- a/f.rb\n+++ b/f.rb\n@@ -1 +1 @@\n-old\n+new"
    td = TaskDiff.new(diff_content: content)
    assert_equal content, td.unified_diff_string
  end

  # --- grouped_lines ---

  test "grouped_lines returns empty for blank diff" do
    td = TaskDiff.new(diff_content: nil)
    assert_equal [], td.grouped_lines
  end

  test "grouped_lines returns non-empty groups for valid diff" do
    td = TaskDiff.new(diff_content: SAMPLE_DIFF)
    groups = td.grouped_lines
    assert groups.length > 0
    assert groups.first[:lines].length > 0
  end

  # --- New validations ---

  test "file_path must not exceed 1000 chars" do
    td = TaskDiff.new(task: @task, file_path: "a" * 1001, diff_type: "modified")
    assert_not td.valid?
    assert td.errors[:file_path].any?
  end

  test "diff_content must not exceed 500000 chars" do
    td = TaskDiff.new(task: @task, file_path: "big.rb", diff_type: "modified", diff_content: "x" * 500_001)
    assert_not td.valid?
    assert td.errors[:diff_content].any?
  end

  test "diff_content nil is allowed" do
    td = TaskDiff.new(task: @task, file_path: "nil_content.rb", diff_type: "modified", diff_content: nil)
    assert td.valid?, "Expected nil diff_content to be valid: #{td.errors.full_messages}"
  end

  test "diff_type is required" do
    td = TaskDiff.new(task: @task, file_path: "no_type.rb", diff_type: nil)
    assert_not td.valid?
    assert td.errors[:diff_type].any?
  end
end
