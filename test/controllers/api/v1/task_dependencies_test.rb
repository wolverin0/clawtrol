# frozen_string_literal: true

require "test_helper"

class Api::V1::TaskDependenciesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @task = tasks(:one)
    @other_task = tasks(:two)
    # Ensure the other_task belongs to same user for dependency testing
    @other_task.update_columns(user_id: @user.id, board_id: @task.board_id)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
    # Clear any fixture-created dependencies
    TaskDependency.where(task: @task).or(TaskDependency.where(depends_on: @task)).delete_all
    TaskDependency.where(task: @other_task).or(TaskDependency.where(depends_on: @other_task)).delete_all
  end

  # --- GET dependencies ---

  test "dependencies returns empty when no dependencies" do
    get dependencies_api_v1_task_url(@task), headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal [], body["dependencies"]
    assert_equal [], body["dependents"]
    assert_equal false, body["blocked"]
    assert_equal [], body["blocking_tasks"]
  end

  test "dependencies returns linked tasks after adding dependency" do
    post add_dependency_api_v1_task_url(@task), headers: @auth_header,
         params: { depends_on_id: @other_task.id }
    assert_response :success

    get dependencies_api_v1_task_url(@task), headers: @auth_header
    assert_response :success

    body = response.parsed_body
    assert_equal 1, body["dependencies"].length
    assert_equal @other_task.id, body["dependencies"].first["id"]
  end

  # --- POST add_dependency ---

  test "add_dependency creates dependency link" do
    assert_difference "TaskDependency.count", 1 do
      post add_dependency_api_v1_task_url(@task), headers: @auth_header,
           params: { depends_on_id: @other_task.id }
    end
    assert_response :success

    body = response.parsed_body
    assert body["success"]
    assert_equal @other_task.id, body["dependency"]["depends_on_id"]
  end

  test "add_dependency requires depends_on_id" do
    post add_dependency_api_v1_task_url(@task), headers: @auth_header
    assert_response :bad_request

    body = response.parsed_body
    assert_match(/depends_on_id/, body["error"])
  end

  test "add_dependency rejects non-existent task" do
    post add_dependency_api_v1_task_url(@task), headers: @auth_header,
         params: { depends_on_id: 999999 }
    assert_response :not_found
  end

  test "add_dependency rejects duplicate" do
    TaskDependency.create!(task: @task, depends_on: @other_task)

    post add_dependency_api_v1_task_url(@task), headers: @auth_header,
         params: { depends_on_id: @other_task.id }
    assert_response :unprocessable_entity
  end

  # --- DELETE remove_dependency ---

  test "remove_dependency removes existing link" do
    TaskDependency.create!(task: @task, depends_on: @other_task)

    assert_difference "TaskDependency.count", -1 do
      delete remove_dependency_api_v1_task_url(@task), headers: @auth_header,
             params: { depends_on_id: @other_task.id }
    end
    assert_response :success

    body = response.parsed_body
    assert body["success"]
  end

  test "remove_dependency requires depends_on_id" do
    delete remove_dependency_api_v1_task_url(@task), headers: @auth_header
    assert_response :bad_request
  end

  test "remove_dependency returns 404 for non-existent dependency" do
    delete remove_dependency_api_v1_task_url(@task), headers: @auth_header,
           params: { depends_on_id: @other_task.id }
    assert_response :not_found
  end

  # --- Authentication ---

  test "dependency endpoints require auth" do
    get dependencies_api_v1_task_url(@task)
    assert_response :unauthorized

    post add_dependency_api_v1_task_url(@task)
    assert_response :unauthorized

    delete remove_dependency_api_v1_task_url(@task)
    assert_response :unauthorized
  end
end
