# frozen_string_literal: true

require "test_helper"

class FactoryControllerTest < ActiveSupport::TestCase
  test "recent_files_changed_summary returns N/A when repo has fewer than 2 commits" do
    controller = FactoryController.new

    assert_equal "N/A", controller.send(:recent_files_changed_summary, "/tmp/repo", 0)
    assert_equal "N/A", controller.send(:recent_files_changed_summary, "/tmp/repo", 1)
  end

  test "recent_files_changed_summary uses bounded commit window and parses summary line" do
    controller = FactoryController.new
    captured_args = nil

    fake_output = <<~DIFF
      app/models/task.rb | 2 ++
      1 file changed, 2 insertions(+)
    DIFF

    controller.stub(:safe_shell, ->(*args) { captured_args = args; fake_output }) do
      summary = controller.send(:recent_files_changed_summary, "/tmp/repo", 99)

      assert_equal "1 file changed, 2 insertions(+)", summary
    end

    assert_equal ["git", "-C", "/tmp/repo", "diff", "--stat", "HEAD~10", "HEAD", "--", "app/", "test/", "db/"], captured_args
  end
end
