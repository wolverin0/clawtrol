# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SwarmTaskContractTest < ActiveSupport::TestCase
  def sample_idea
    OpenStruct.new(
      id: 77,
      title: "Implement queue hardening",
      description: "Tighten queue orchestration and recoverability.",
      category: "code",
      difficulty: "standard",
      source: "manual",
      project: "clawtrol",
      pipeline_type: "feature",
      estimated_minutes: 45
    )
  end

  test "build generates contract with required fields" do
    contract = SwarmTaskContract.build(
      idea: sample_idea,
      board_id: 3,
      model: "codex",
      overrides: {
        orchestrator: "swarm-core",
        acceptance_criteria: ["all tests pass"],
        required_artifacts: ["artifact.md"],
        skills: ["ruby", "rails"]
      }
    )

    assert_equal "2026-02-23.v1", contract["version"]
    assert_equal "swarm-core", contract["orchestrator"]
    assert_equal "codex", contract.dig("execution", "model")
    assert_equal 3, contract.dig("execution", "board_id")
    assert_equal ["all tests pass"], contract["acceptance_criteria"]
    assert_equal ["artifact.md"], contract["required_artifacts"]
    assert_equal ["ruby", "rails"], contract["skills"]
    assert_match(/\A[a-f0-9]{16}\z/, contract["contract_id"])
  end

  test "validate flags missing required fields" do
    result = SwarmTaskContract.validate({ "version" => "v1" })

    assert_not result[:valid]
    assert_includes result[:errors], "contract_id missing"
    assert_includes result[:errors], "idea.title missing"
    assert_includes result[:errors], "execution.board_id missing"
  end

  test "render_execution_plan includes contract data" do
    contract = SwarmTaskContract.build(idea: sample_idea, board_id: 9, model: "gemini")

    plan = SwarmTaskContract.render_execution_plan(contract)

    assert_includes plan, "Swarm Contract ID: #{contract['contract_id']}"
    assert_includes plan, "Acceptance Criteria:"
    assert_includes plan, "Required Artifacts:"
  end
end
