# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class LearningProposalsImportServiceTest < ActiveSupport::TestCase
  test "imports pending recurring learnings and is idempotent" do
    user = users(:one)

    Dir.mktmpdir do |workspace|
      FileUtils.mkdir_p(File.join(workspace, "memory", "learnings"))
      FileUtils.mkdir_p(File.join(workspace, "mind"))
      File.write(File.join(workspace, "mind", "ERRORS.md"), "# Errors\n")
      File.write(File.join(workspace, "mind", "DECISIONS.md"), "# Decisions\n")

      File.write(File.join(workspace, "memory", "learnings", "2026-02.md"), <<~MD)
        # Learnings 2026-02

        ## [2026-02-23] [local_paths] avoid local filesystem paths
        **Contexto:** test context one
        **Error:** reported local path
        **Corrección:** use viewer links
        **Trigger:** final report
        **Recurrencia:** 2
        **Estado:** pending_review

        ## [2026-02-23] [done_without_proof] avoid done without proof
        **Contexto:** test context two
        **Error:** said done without evidence
        **Corrección:** include curl/log/snapshot
        **Trigger:** completion message
        **Recurrencia:** 4
        **Estado:** pending_review

        ## [2026-02-23] [noise] should be skipped by threshold
        **Contexto:** test context three
        **Error:** low recurrence
        **Corrección:** no-op
        **Trigger:** none
        **Recurrencia:** 1
        **Estado:** pending_review
      MD

      service = LearningProposalsImportService.new(user, workspace_root: workspace)

      assert_difference -> { user.learning_proposals.count }, 2 do
        result = service.call
        assert_equal 2, result[:created]
        assert_equal 1, result[:skipped]
        assert_empty result[:errors]
      end

      assert user.learning_proposals.exists?(target_file: "mind/DECISIONS.md")
      assert user.learning_proposals.exists?(target_file: "mind/ERRORS.md")

      second = service.call
      assert_equal 0, second[:created]
      assert_operator second[:skipped], :>=, 2
      assert_empty second[:errors]
    end
  end
end
