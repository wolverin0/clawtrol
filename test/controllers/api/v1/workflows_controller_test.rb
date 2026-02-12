require "test_helper"

class Api::V1::WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workflow = workflows(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
  end

  test "run executes workflow and returns per-node results" do
    post run_api_v1_workflow_url(@workflow), headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert body["runId"].present?
    assert_equal @workflow.id, body.dig("workflow", "id")
    assert_equal "ok", body["status"]

    assert_kind_of Array, body["nodes"]
    assert_equal 1, body["nodes"].length
    assert_equal "trigger", body["nodes"][0]["type"]
    assert_equal "ok", body["nodes"][0]["status"]
  end

  test "run returns 422 for invalid DAG" do
    @workflow.update!(definition: {
      nodes: [
        { id: "a", type: "trigger", label: "A", x: 0, y: 0, props: {} },
        { id: "b", type: "agent", label: "B", x: 0, y: 0, props: {} }
      ],
      edges: [
        { from: "a", to: "b" },
        { from: "b", to: "a" }
      ]
    })

    post run_api_v1_workflow_url(@workflow), headers: @auth_header
    assert_response :unprocessable_entity

    body = response.parsed_body
    assert_equal "invalid", body["status"]
    assert body["errors"].any?
  end
end
