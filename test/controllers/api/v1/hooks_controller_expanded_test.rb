require "test_helper"

class Api::V1::HooksControllerExpandedTest < ActionDispatch::IntegrationTest
  setup do
    @task = tasks(:one)
    @token = Rails.application.config.hooks_token
  end

  # === task_outcome auth ===

  test "task_outcome rejects missing token" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "1", run_id: SecureRandom.uuid },
         as: :json
    assert_response :unauthorized
  end

  test "task_outcome rejects invalid token" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "1", run_id: SecureRandom.uuid },
         headers: { "X-Hook-Token" => "bad_token" },
         as: :json
    assert_response :unauthorized
  end

  test "task_outcome rejects invalid version" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "99", run_id: SecureRandom.uuid },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :unprocessable_entity
  end

  test "task_outcome rejects invalid run_id" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "1", run_id: "not-a-uuid" },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :unprocessable_entity
  end

  test "task_outcome with valid params creates TaskRun" do
    run_id = SecureRandom.uuid
    assert_difference "TaskRun.count", 1 do
      post "/api/v1/hooks/task_outcome",
           params: {
             task_id: @task.id,
             version: "1",
             run_id: run_id,
             summary: "All tests pass",
             needs_follow_up: false,
             achieved: ["wrote tests"],
             evidence: ["test output"],
             remaining: []
           },
           headers: { "X-Hook-Token" => @token },
           as: :json
    end
    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert_equal "in_review", @task.reload.status
  end

  test "task_outcome is idempotent on same run_id" do
    run_id = SecureRandom.uuid
    2.times do
      post "/api/v1/hooks/task_outcome",
           params: { task_id: @task.id, version: "1", run_id: run_id, summary: "done",
                     needs_follow_up: false, recommended_action: "in_review" },
           headers: { "X-Hook-Token" => @token },
           as: :json
      assert_response :success
    end
    assert_equal 1, TaskRun.where(run_id: run_id).count
  end

  test "task_outcome returns not_found for missing task" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: 999999, version: "1", run_id: SecureRandom.uuid },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :not_found
  end

  test "task_outcome rejects invalid recommended_action" do
    post "/api/v1/hooks/task_outcome",
         params: {
           task_id: @task.id, version: "1", run_id: SecureRandom.uuid,
           recommended_action: "hack_the_planet"
         },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :unprocessable_entity
  end

  test "task_outcome requeue_same_task requires next_prompt" do
    post "/api/v1/hooks/task_outcome",
         params: {
           task_id: @task.id, version: "1", run_id: SecureRandom.uuid,
           needs_follow_up: true, recommended_action: "requeue_same_task"
         },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :unprocessable_entity
    assert_match(/next_prompt/, response.parsed_body["error"])
  end

  # === agent_complete auth ===

  test "agent_complete rejects missing token" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "done" },
         as: :json
    assert_response :unauthorized
  end

  test "agent_complete with valid token updates task to in_review" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "All good" },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :success
    assert_equal "in_review", @task.reload.status
    assert_match(/All good/, @task.description)
  end

  test "agent_complete finds task by session_key" do
    @task.update!(agent_session_key: "test-key-123")
    post "/api/v1/hooks/agent_complete",
         params: { session_key: "test-key-123", findings: "Found via key" },
         headers: { "X-Hook-Token" => @token },
         as: :json
    assert_response :success
    assert_match(/Found via key/, @task.reload.description)
  end
end
