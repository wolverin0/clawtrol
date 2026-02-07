require "test_helper"

class Api::V1::HooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @task = tasks(:one)
    @token = Rails.application.config.hooks_token
  end

  test "agent_complete returns unauthorized with bad token" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "nope" },
         headers: { "X-Hook-Token" => "wrong" }

    assert_response :unauthorized
  end

  test "agent_complete updates task and prepends agent output" do
    @task.update!(description: "Original description")

    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "Hook findings", session_id: "sess-123" },
         headers: { "X-Hook-Token" => @token }

    assert_response :success

    @task.reload
    assert_equal "in_review", @task.status
    assert_equal "sess-123", @task.agent_session_id
    assert_match(/\A## Agent Output\n\nHook findings\n\n---\n\nOriginal description\z/, @task.description)
  end

  test "agent_complete replaces existing top output block on duplicate calls" do
    @task.update!(description: "## Agent Output\n\nOld findings\n\n---\n\nOriginal description")

    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "New findings" },
         headers: { "X-Hook-Token" => @token }

    assert_response :success

    @task.reload
    assert_equal "in_review", @task.status
    assert_match(/\A## Agent Output\n\nNew findings\n\n---\n\nOriginal description\z/, @task.description)
  end
end
