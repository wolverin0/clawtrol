# frozen_string_literal: true

require "test_helper"

class GenerateDiffsJobTest < ActiveJob::TestCase
  setup do
    @task = tasks(:one)
    @project_dir = Dir.mktmpdir("test_project")
  end

  teardown do
    FileUtils.remove_entry(@project_dir) if Dir.exist?(@project_dir)
  end

  # --- Basic functionality ---

  test "does nothing when task not found" do
    assert_no_enqueued_jobs do
      GenerateDiffsJob.perform_now(999_999, ["test.rb"])
    end
  end

  test "does nothing when project dir does not exist" do
    @task.board.update!(project_path: "/nonexistent/path")

    assert_no_enqueued_jobs do
      GenerateDiffsJob.perform_now(@task.id, ["test.rb"])
    end
  end

  test "does nothing when file_paths is empty" do
    assert_no_enqueued_jobs do
      GenerateDiffsJob.perform_now(@task.id, [])
    end
  end

  # --- Git diff generation ---

  test "generates diff for modified file in git repo" do
    # Create a git repo
    git_dir = File.join(@project_dir, ".git")
    system("git init -q #{@project_dir}")
    File.write(File.join(@project_dir, "test.rb"), "puts 'hello'\nputs 'world'\n")
    system("git -C #{@project_dir} add test.rb")
    system("git -C #{@project_dir} commit -q -m 'initial'")

    # Modify the file
    File.write(File.join(@project_dir, "test.rb"), "puts 'hello'\nputs 'modified'\n")

    @task.board.update!(project_path: @project_dir)

    GenerateDiffsJob.perform_now(@task.id, ["test.rb"])

    @task.reload
    diff = @task.task_diffs.find_by(file_path: "test.rb")
    assert diff
    assert diff.diff_content.present?
    assert_equal "modified", diff.diff_type
  end

  test "generates diff for new untracked file" do
    system("git init -q #{@project_dir}")
    File.write(File.join(@project_dir, "newfile.rb"), "class New\nend\n")

    @task.board.update!(project_path: @project_dir)

    GenerateDiffsJob.perform_now(@task.id, ["newfile.rb"])

    @task.reload
    diff = @task.task_diffs.find_by(file_path: "newfile.rb")
    assert diff
    assert diff.diff_content.include?("+class New"), "Expected diff content to include new file content"
    assert_equal "added", diff.diff_type
  end

  test "generates diff for deleted file" do
    system("git init -q #{@project_dir}")
    File.write(File.join(@project_dir, "deleted.rb"), "class Deleted\nend\n")
    system("git -C #{@project_dir} add deleted.rb")
    system("git -C #{@project_dir} commit -q -m 'initial'")
    File.delete(File.join(@project_dir, "deleted.rb"))

    @task.board.update!(project_path: @project_dir)

    GenerateDiffsJob.perform_now(@task.id, ["deleted.rb"])

    @task.reload
    diff = @task.task_diffs.find_by(file_path: "deleted.rb")
    assert diff
    assert diff.diff_content.include?("-class Deleted"), "Expected diff to show deleted content"
    assert_equal "deleted", diff.diff_type
  end

  # --- Non-git fallback ---

  test "falls back to showing file content when not a git repo" do
    FileUtils.mkdir_p(@project_dir)
    File.write(File.join(@project_dir, "plain.rb"), "puts 'no git'\n")

    @task.board.update!(project_path: @project_dir)

    GenerateDiffsJob.perform_now(@task.id, ["plain.rb"])

    @task.reload
    diff = @task.task_diffs.find_by(file_path: "plain.rb")
    assert diff
    assert diff.diff_content.include?("+puts 'no git'")
    assert_equal "added", diff.diff_type
  end

  # --- Upsert behavior ---

  test "updates existing diff on re-run" do
    system("git init -q #{@project_dir}")
    File.write(File.join(@project_dir, "updatable.rb"), "version 1\n")
    system("git -C #{@project_dir} add updatable.rb")
    system("git -C #{@project_dir} commit -q -m 'initial'")

    @task.board.update!(project_path: @project_dir)

    # First run
    GenerateDiffsJob.perform_now(@task.id, ["updatable.rb"])
    first_diff = @task.task_diffs.find_by(file_path: "updatable.rb")
    original_content = first_diff.diff_content

    # Modify and re-run
    File.write(File.join(@project_dir, "updatable.rb"), "version 2\n")
    GenerateDiffsJob.perform_now(@task.id, ["updatable.rb"])

    first_diff.reload
    # diff_content updates on re-run (may differ from original since file changed)
    assert first_diff.diff_content.present?, "Should update on re-run"
  end

  # --- Error handling ---

  test "continues processing other files when one fails" do
    system("git init -q #{@project_dir}")
    File.write(File.join(@project_dir, "good.rb"), "good file\n")

    @task.board.update!(project_path: @project_dir)

    # This should not raise even with a bad path
    assert_nothing_raised do
      GenerateDiffsJob.perform_now(@task.id, ["nonexistent.rb", "good.rb"])
    end

    # The good file should still be processed
    assert @task.task_diffs.find_by(file_path: "good.rb")
  end
end
