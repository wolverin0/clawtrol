# frozen_string_literal: true

require "test_helper"

class ZeroclawAuditorJobDedupeTest < ActiveJob::TestCase
  test "skips recently audited task on cron sweep trigger" do
    task = Task.create!(
      user: users(:one),
      board: boards(:one),
      name: "Recently audited task",
      status: :in_review,
      assigned_to_agent: true,
      tags: ["report"],
      description: "## Agent Output\nSummary one\nSummary two\nhttps://example.com",
      output_files: ["https://example.com/report.md"],
      review_result: {},
      state_data: { "auditor" => { "last" => { "completed_at" => 1.minute.ago.iso8601 } } }
    )

    assert_no_changes -> { task.reload.review_result } do
      ZeroclawAuditorJob.perform_now(task.id, trigger: "cron_sweep")
    end

    assert_nil task.reload.review_result["auditor"]
  end
end
