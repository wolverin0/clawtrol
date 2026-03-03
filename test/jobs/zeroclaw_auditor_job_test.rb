# frozen_string_literal: true

require "test_helper"

class ZeroclawAuditorJobTest < ActiveJob::TestCase
  test "audits in_review task" do
    task = Task.create!(
      user: users(:one),
      board: boards(:one),
      name: "Job audit task",
      status: :in_review,
      assigned_to_agent: true,
      tags: ["report"],
      description: "## Agent Output\nSummary line one\nSummary line two\nhttps://example.com",
      output_files: ["https://example.com/report.md"]
    )

    ZeroclawAuditorJob.perform_now(task.id, trigger: "test")

    task.reload
    assert task.review_result.is_a?(Hash)
    assert task.review_result["auditor"].is_a?(Hash)
    assert_includes %w[PASS FAIL_REWORK NEEDS_HUMAN], task.review_result.dig("auditor", "verdict")
  end
end
