# frozen_string_literal: true

require "test_helper"

class Api::V1::TasksControllerExpandedTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @task = tasks(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
  end

  # === Agent Claim/Unclaim via API ===

  test "claim moves task to in_progress" do
    @task.update!(status: :up_next, assigned_to_agent: true, assigned_at: Time.current)
    patch claim_api_v1_task_url(@task), headers: @auth_header
    assert_response :success
    @task.reload
    assert_equal "in_progress", @task.status
    assert @task.agent_claimed_at.present?
  end

  test "unclaim releases task" do
    # Create lease first, then update status (validation requires active lease for in_progress)
    now = Time.current
    RunnerLease.create!(task: @task, agent_name: "test", lease_token: SecureRandom.hex(24), source: "test", started_at: now, last_heartbeat_at: now, expires_at: now + 1.hour)
    @task.update!(status: :in_progress, assigned_to_agent: true, assigned_at: now, agent_claimed_at: now)
    patch unclaim_api_v1_task_url(@task), headers: @auth_header
    assert_response :success
    @task.reload
    assert_nil @task.agent_claimed_at
  end

  # === Move via API ===

  test "move changes task status" do
    patch move_api_v1_task_url(@task), params: { status: "in_progress" }, headers: @auth_header
    assert_response :success
    assert_equal "in_progress", @task.reload.status
  end

  # === Next endpoint ===

  test "next returns next assignable task" do
    @task.update!(status: :up_next, assigned_to_agent: true, blocked: false)
    get next_api_v1_tasks_url, headers: @auth_header
    assert_response :success
  end

test "queue_health returns orchestration snapshot" do
  get queue_health_api_v1_tasks_url, headers: @auth_header
  assert_response :success

  body = JSON.parse(response.body)
  assert body.key?("queue_depth")
  assert body.key?("active_in_progress")
  assert body.key?("inflight_by_model")
end

  # === Task scoping ===

  test "cannot update other users task" do
    other_task = tasks(:two)
    patch api_v1_task_url(other_task), params: { task: { name: "Hacked" } }, headers: @auth_header
    assert_response :not_found
    assert_not_equal "Hacked", other_task.reload.name
  end

  test "cannot delete other users task" do
    other_task = tasks(:two)
    assert_no_difference "Task.count" do
      delete api_v1_task_url(other_task), headers: @auth_header
    end
    assert_response :not_found
  end

  # === Agent info headers ===

  test "updates agent name from header" do
    get api_v1_tasks_url, headers: @auth_header.merge(
      "X-Agent-Name" => "TestBot",
      "X-Agent-Emoji" => "🤖"
    )
    assert_response :success
    @user.reload
    assert_equal "TestBot", @user.agent_name
    assert_equal "🤖", @user.agent_emoji
  end

  # === Errored count ===

  test "errored_count endpoint" do
    get errored_count_api_v1_tasks_url, headers: @auth_header
    assert_response :success
  end
end
