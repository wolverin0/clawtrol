# frozen_string_literal: true

require "test_helper"

class Api::V1::OrchestrationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = Board.create!(id: 5, user: @user, name: "Orchestration", position: 50)
    @token = @user.api_tokens.create!(
      name: "Wezbridge",
      scopes: ["orchestration_bridge:sync"]
    )
    @headers = {
      "Authorization" => "Bearer #{@token.raw_token}",
      "Content-Type" => "application/json"
    }
  end

  test "requires a live token with orchestration scope" do
    post sync_path, params: base_payload.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized

    unscoped = @user.api_tokens.create!(name: "Unscoped")
    post sync_path, params: base_payload.to_json, headers: bearer_headers(unscoped.raw_token)
    assert_response :forbidden

    @token.revoke!
    post sync_path, params: base_payload.to_json, headers: @headers
    assert_response :unauthorized
  end

  test "upserts task run event and reply idempotently without changing brief" do
    payload = base_payload.merge(
      tasks: [task_snapshot],
      events: [event_snapshot],
      messages: [message_snapshot]
    )

    post sync_path, params: payload.to_json, headers: @headers
    assert_response :success
    task = @user.tasks.find_by!(origin_session_key: "wezbridge:primary:task:T-0001")
    run = task.task_runs.find_by!(external_source_key: external_run_key)

    assert_equal 5, task.board_id
    assert_equal "Original brief", task.description
    assert_equal "in_progress", task.status
    refute task.assigned_to_agent?
    assert_equal "running", task.state_data.dig("orchestration", "source_state")
    source = @user.orchestration_sources.find_by!(profile: "primary")
    assert_equal "healthy", source.status
    refute source.health.key?("token")
    assert_equal 1, run.run_number
    assert_equal 1, task.agent_activity_events.count
    event = task.agent_activity_events.first
    assert_equal 1_000_000_000_043, event.seq
    refute event.payload.key?("authorization")
    assert_equal 1, task.agent_messages.count

    replay = payload.deep_dup
    replay[:tasks][0][:brief] = "Attempted rewrite"
    replay[:tasks][0][:title] = "Updated title"
    post sync_path, params: replay.to_json, headers: @headers
    assert_response :success

    assert_equal "Original brief", task.reload.description
    assert_equal "Updated title", task.name
    assert_equal 1, task.task_runs.count
    assert_equal 1, task.agent_activity_events.count
    assert_equal 1, task.agent_messages.count
    assert_equal 2, response.parsed_body.dig("accepted", "duplicates")
  end

  test "returns pending intents until an applied result is received" do
    post sync_path, params: base_payload.merge(tasks: [task_snapshot]).to_json, headers: @headers
    source = @user.orchestration_sources.find_by!(profile: "primary")
    task = @user.tasks.find_by!(origin_session_key: "wezbridge:primary:task:T-0001")
    intent = @user.orchestration_intents.create!(
      orchestration_source: source,
      task:,
      kind: "approve",
      payload: {}
    )

    post sync_path, params: base_payload.to_json, headers: @headers
    assert_equal [intent.id], response.parsed_body["intents"].pluck("id")

    result = { id: intent.id, status: "applied", result: { ledger_id: "T-0001" } }
    post sync_path, params: base_payload.merge(intent_results: [result]).to_json, headers: @headers
    assert_response :success
    assert_equal "applied", intent.reload.status
    assert_equal [], response.parsed_body["intents"]

    post sync_path, params: base_payload.merge(intent_results: [result]).to_json, headers: @headers
    assert_response :success
    assert_equal 1, response.parsed_body.dig("accepted", "duplicates")
  end

  test "preserves pane snapshot when a delta heartbeat omits panes" do
    post sync_path, params: base_payload.to_json, headers: @headers
    assert_response :success
    source = @user.orchestration_sources.find_by!(profile: "primary")
    assert_equal [{ "id" => 0, "state" => "idle" }], source.panes

    delta = base_payload.except(:panes)
    delta[:generated_at] = "2026-07-27T20:00:05Z"
    post sync_path, params: delta.to_json, headers: @headers
    assert_response :success

    assert_equal [{ "id" => 0, "state" => "idle" }], source.reload.panes
  end

  test "keeps profiles isolated by authenticated user" do
    post sync_path, params: base_payload.merge(tasks: [task_snapshot]).to_json, headers: @headers

    other_user = users(:two)
    Board.create!(id: 15, user: other_user, name: "Other projection", position: 50)
    other_token = other_user.api_tokens.create!(
      name: "Other bridge",
      scopes: ["orchestration_bridge:sync"]
    )
    other_payload = base_payload.merge(tasks: [task_snapshot.merge(id: "T-9999")])
    other_payload[:tasks][0][:board_id] = 15

    post sync_path, params: other_payload.to_json, headers: bearer_headers(other_token.raw_token)
    assert_response :unprocessable_entity
    assert_equal 1, @user.tasks.where("origin_session_key LIKE 'wezbridge:%'").count
    assert_equal 0, other_user.tasks.where("origin_session_key LIKE 'wezbridge:%'").count
  end

  private

  def sync_path
    "/api/v1/orchestration/sync"
  end

  def base_payload
    {
      profile: "primary",
      generated_at: "2026-07-27T20:00:00Z",
      health: { status: "ok", last_error: nil, token: "must-be-dropped" },
      panes: [{ id: 0, state: "idle" }],
      tasks: [],
      events: [],
      messages: [],
      intent_results: []
    }
  end

  def task_snapshot
    {
      id: "T-0001",
      title: "Mirrored task",
      brief: "Original brief",
      project: "whatsappbot",
      kind: "task",
      state: "running",
      priority: "high",
      attempt: 1,
      depends_on: [],
      acceptance: ["focused tests pass"],
      evidence: [],
      updated_at: "2026-07-27T20:00:05Z"
    }
  end

  def event_snapshot
    {
      external_id: "events-v1:42",
      task_id: "T-0001",
      attempt: 1,
      seq: 1_000_000_000_043,
      timestamp: "2026-07-27T20:00:06Z",
      event_type: "status",
      level: "info",
      message: "Working",
      payload: { authorization: "must-be-dropped" }
    }
  end

  def message_snapshot
    {
      external_id: "messages-v1:12",
      task_id: "T-0001",
      provenance: "orchestrator",
      message_type: "progress",
      content: "Started the task",
      sender_name: "Pane 0",
      timestamp: "2026-07-27T20:00:07Z"
    }
  end

  def external_run_key
    "wezbridge:user-#{@user.id}:primary:T-0001:attempt:1"
  end

  def bearer_headers(token)
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end
end
