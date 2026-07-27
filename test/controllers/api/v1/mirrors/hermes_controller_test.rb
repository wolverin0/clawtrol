# frozen_string_literal: true

require "test_helper"

class Api::V1::Mirrors::HermesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = Board.create!(id: 5, user: @user, name: "Hermes Mirror", position: 50)
    @token = @user.api_tokens.create!(
      name: "Hermes mirror",
      scopes: ["hermes_mirror:write"]
    )
    @headers = {
      "Authorization" => "Bearer #{@token.raw_token}",
      "Content-Type" => "application/json"
    }
  end

  test "requires a live token with hermes mirror write scope" do
    post sessions_path, params: session_payload.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized

    unscoped = @user.api_tokens.create!(name: "Unscoped")
    post sessions_path, params: session_payload.to_json,
      headers: bearer_headers(unscoped.raw_token)
    assert_response :forbidden

    @token.revoke!
    post sessions_path, params: session_payload.to_json, headers: @headers
    assert_response :unauthorized

    expired = @user.api_tokens.create!(
      name: "Expired mirror",
      scopes: ["hermes_mirror:write"],
      expires_at: 1.minute.ago
    )
    post sessions_path, params: session_payload.to_json,
      headers: bearer_headers(expired.raw_token)
    assert_response :unauthorized
  end

  test "mirrors a session idempotently without rewriting its brief" do
    post sessions_path, params: session_payload.to_json, headers: @headers
    assert_response :created
    first_response = response.parsed_body
    task = Task.find(first_response["task_id"])
    task_run = TaskRun.find_by!(run_id: first_response["run_id"])

    assert_equal 5, task.board_id
    assert_equal "hermes:primary:session-123", task.origin_session_key
    assert_equal "Original short brief", task.description
    assert_match(/\Ahermes:user-\d+:primary:session-123\z/, task_run.external_source_key)

    replay = session_payload.merge(brief: "Attempted replacement", title: "Updated title")
    post sessions_path, params: replay.to_json, headers: @headers
    assert_response :ok

    assert_equal first_response["task_id"], response.parsed_body["task_id"]
    assert_equal first_response["run_id"], response.parsed_body["run_id"]
    assert_equal "Original short brief", task.reload.description
    assert_equal "Updated title", task.name
    assert_equal 1, @user.tasks.where(origin_session_key: task.origin_session_key).count
  end

  test "appends event batches idempotently by run id and sequence" do
    create_mirrored_session
    payload = identity.merge(
      events: [
        {
          seq: 1,
          timestamp: "2026-07-26T12:00:00Z",
          event_type: "message",
          message: "Started"
        },
        {
          seq: 2,
          timestamp: "2026-07-26T12:00:01Z",
          event_type: "status",
          message: "Working",
          payload: { redacted: true }
        }
      ]
    )

    post events_path, params: payload.to_json, headers: @headers
    assert_response :ok
    assert_equal 2, response.parsed_body["created"]
    assert_equal 0, response.parsed_body["duplicates"]

    post events_path, params: payload.to_json, headers: @headers
    assert_response :ok
    assert_equal 0, response.parsed_body["created"]
    assert_equal 2, response.parsed_body["duplicates"]

    run_id = response.parsed_body["run_id"]
    assert_equal 2, AgentActivityEvent.where(run_id:).count
    assert_equal "hermes_mirror", AgentActivityEvent.find_by!(run_id:, seq: 1).source
  end

  test "records terminal outcome on TaskRun and leaves Task description unchanged" do
    task_id = create_mirrored_session["task_id"]
    payload = identity.merge(
      terminal_state: "completed",
      ended_at: "2026-07-26T12:30:00Z",
      outcome: "Redacted mirrored outcome"
    )

    post completions_path, params: payload.to_json, headers: @headers
    assert_response :ok
    assert_equal false, response.parsed_body["idempotent"]

    task = Task.find(task_id)
    task_run = task.task_runs.find_by!(run_id: response.parsed_body["run_id"])
    assert task.done?
    assert_equal "Original short brief", task.description
    assert_equal "Redacted mirrored outcome", task_run.agent_output
    assert_equal "completed", task_run.raw_payload["mirror_terminal_state"]

    post completions_path, params: payload.to_json, headers: @headers
    assert_response :ok
    assert_equal true, response.parsed_body["idempotent"]
    assert_equal 1, task.task_runs.count
  end

  test "rejects the ALL aggregator as a mirror destination" do
    @board.update!(name: "ALL", is_aggregator: true)

    post sessions_path, params: session_payload.to_json, headers: @headers

    assert_response :unprocessable_entity
    assert_match(/ALL aggregator/, response.parsed_body["error"])
    assert_nil Task.find_by(origin_session_key: "hermes:primary:session-123")
  end

  private

  def sessions_path
    "/api/v1/mirrors/hermes/sessions"
  end

  def events_path
    "/api/v1/mirrors/hermes/events"
  end

  def completions_path
    "/api/v1/mirrors/hermes/completions"
  end

  def identity
    { profile: "primary", session_id: "session-123" }
  end

  def session_payload
    identity.merge(title: "Mirrored session", brief: "Original short brief")
  end

  def create_mirrored_session
    post sessions_path, params: session_payload.to_json, headers: @headers
    assert_response :created
    response.parsed_body
  end

  def bearer_headers(raw_token)
    {
      "Authorization" => "Bearer #{raw_token}",
      "Content-Type" => "application/json"
    }
  end
end
