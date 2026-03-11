# frozen_string_literal: true

require "test_helper"

module Zeroclaw
  class AuditorServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @board = boards(:one)
      @artifact = Rails.root.join("tmp", "auditor_service_test_artifact.md")
      File.write(@artifact, "# auditor artifact\n")
    end

    teardown do
      File.delete(@artifact) if File.exist?(@artifact)
    end

    test "returns PASS for coding task with validation evidence" do
      task = Task.create!(
        user: @user,
        board: @board,
        name: "Coding task pass",
        status: :in_review,
        assigned_to_agent: true,
        tags: ["coding"],
        validation_status: "passed",
        output_files: [@artifact.to_s],
        description: <<~TEXT,
          ## Agent Output
          Implemented feature. Tests passed and lint passed.

          Summary:
          - done
        TEXT
        review_config: {
          "swarm_contract" => {
            "acceptance_criteria" => ["Feature implemented", "Tests pass"]
          }
        }
      )

      result = Zeroclaw::AuditorService.new(task, trigger: "test").call
      task.reload

      assert_equal "PASS", result[:verdict]
      assert_equal "passed", task.review_status
      assert_equal "PASS", task.review_result.dig("auditor", "verdict")
      assert_equal "in_review", task.status
      assert_includes task.description, "## Auditor Verdict"
    end

    test "returns FAIL_REWORK and increments rework count on missing evidence" do
      task = Task.create!(
        user: @user,
        board: @board,
        name: "Coding task fail",
        status: :in_review,
        assigned_to_agent: true,
        tags: ["coding"],
        output_files: [],
        description: "## Agent Output\nImplemented core flow.\n\nSummary:\n- Pending validation artifact",
        review_config: {
          "swarm_contract" => {
            "acceptance_criteria" => ["Core flow implemented"]
          }
        }
      )

      result = Zeroclaw::AuditorService.new(task, trigger: "test").call
      task.reload

      assert_equal "FAIL_REWORK", result[:verdict]
      assert_equal "failed", task.review_status
      assert_equal "up_next", task.status
      assert task.assigned_to_agent, "task should be flagged assigned_to_agent for re-queue"
      assert_equal 1, task.state_data.dig("auditor", "rework_count")
      assert result[:required_fixes].any?
    end

    test "returns NEEDS_HUMAN after max rework loops" do
      task = Task.create!(
        user: @user,
        board: @board,
        name: "Coding task needs human",
        status: :in_review,
        assigned_to_agent: true,
        tags: ["coding"],
        output_files: [],
        state_data: { "auditor" => { "rework_count" => 2 } },
        description: "## Agent Output\nTBD"
      )

      result = Zeroclaw::AuditorService.new(task, trigger: "test").call
      task.reload

      assert_equal "NEEDS_HUMAN", result[:verdict]
      assert_equal "in_review", task.status
      assert_equal "failed", task.review_status
      assert_equal "NEEDS_HUMAN", task.review_result.dig("auditor", "verdict")
    end
  end
end
