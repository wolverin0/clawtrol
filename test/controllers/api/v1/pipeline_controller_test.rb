# frozen_string_literal: true

require "test_helper"

class Api::V1::PipelineControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
  end

  # --- Authentication ---

  test "returns unauthorized without token" do
    get api_v1_pipeline_status_url
    assert_response :unauthorized
  end

  test "returns unauthorized with invalid token" do
    get api_v1_pipeline_status_url, headers: { "Authorization" => "Bearer invalid_token" }
    assert_response :unauthorized
  end

  test "authenticates with valid API token" do
    get api_v1_pipeline_status_url, headers: @auth_header
    assert_response :success
  end

  # --- Status ---

  test "status returns pipeline overview" do
    get api_v1_pipeline_status_url, headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert data.key?("observation_mode")
    assert data.key?("total_pipeline_tasks")
    assert data.key?("by_stage")
    assert data.key?("by_model")
    assert data.key?("by_type")
    assert data.key?("recent")
  end

  # --- Task log ---

  test "task_log returns pipeline log for a task" do
    task = Task.create!(name: "Pipeline log test", board: @board, user: @user)

    get "/api/v1/pipeline/task/#{task.id}/log", headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert_equal task.id, data["task_id"]
    assert data.key?("pipeline_stage")
    assert data.key?("log")
  end

  test "task_log returns not found for missing task" do
    get "/api/v1/pipeline/task/999999/log", headers: @auth_header
    assert_response :not_found
  end

  # --- Enable/Disable board ---

  test "enable_board enables pipeline on board" do
    @board.update!(pipeline_enabled: false)

    post "/api/v1/pipeline/enable_board/#{@board.id}", headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert data["success"]
    assert @board.reload.pipeline_enabled?
  end

  test "disable_board disables pipeline on board" do
    @board.update!(pipeline_enabled: true)

    post "/api/v1/pipeline/disable_board/#{@board.id}", headers: @auth_header
    assert_response :success

    data = response.parsed_body
    assert data["success"]
    refute @board.reload.pipeline_enabled?
  end

  # --- Reprocess ---

  test "reprocess resets pipeline state and enqueues job" do
    task = Task.create!(
      name: "Reprocess test", board: @board, user: @user,
      pipeline_stage: "routed", pipeline_type: "quick-fix",
      routed_model: "glm"
    )

    assert_enqueued_with(job: PipelineProcessorJob) do
      post "/api/v1/pipeline/reprocess/#{task.id}", headers: @auth_header
    end

    assert_response :success
    task.reload
    assert_equal "unstarted", task.pipeline_stage
    assert_nil task.pipeline_type
    assert_nil task.routed_model
  end
end
