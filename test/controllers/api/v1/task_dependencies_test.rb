require "test_helper"

class Api::V1::TaskDependenciesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task1 = @board.tasks.create!(user: @user, name: "Task 1", status: :inbox)
    @task2 = @board.tasks.create!(user: @user, name: "Task 2", status: :inbox)
    @headers = {
      "Authorization" => "Bearer test_token_one_abc123def456",
      "Content-Type" => "application/json"
    }
  end

  test "GET dependencies returns task's dependencies" do
    @task1.add_dependency!(@task2)
    
    get dependencies_api_v1_task_path(@task1), headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal 1, json["dependencies"].count
    assert_equal @task2.id, json["dependencies"].first["id"]
    assert json["blocked"]
  end

  test "POST add_dependency adds a dependency" do
    post add_dependency_api_v1_task_path(@task1),
      params: { depends_on_id: @task2.id }.to_json,
      headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["blocked"]
    assert_includes @task1.reload.dependencies, @task2
  end

  test "POST add_dependency returns error for invalid dependency" do
    # Try to create self-dependency
    post add_dependency_api_v1_task_path(@task1),
      params: { depends_on_id: @task1.id }.to_json,
      headers: @headers
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].present?
  end

  test "DELETE remove_dependency removes a dependency" do
    @task1.add_dependency!(@task2)
    assert @task1.blocked?
    
    delete "#{remove_dependency_api_v1_task_path(@task1)}?depends_on_id=#{@task2.id}",
      headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    refute json["blocked"]
    refute_includes @task1.reload.dependencies, @task2
  end

  test "DELETE remove_dependency returns error for non-existent dependency" do
    delete "#{remove_dependency_api_v1_task_path(@task1)}?depends_on_id=#{@task2.id}",
      headers: @headers
    
    assert_response :not_found
  end

  test "task_json includes dependencies info" do
    @task1.add_dependency!(@task2)
    
    get api_v1_task_path(@task1), headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["blocked"]
    assert_equal 1, json["dependencies"].count
    assert_equal @task2.id, json["dependencies"].first["id"]
    assert_equal 1, json["blocking_tasks"].count
  end
end
