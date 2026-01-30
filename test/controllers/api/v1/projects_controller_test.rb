require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_token = api_tokens(:one)
    @project = projects(:one)
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
  end

  # Authentication tests
  test "returns unauthorized without token" do
    get api_v1_projects_url
    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "returns unauthorized with invalid token" do
    get api_v1_projects_url, headers: { "Authorization" => "Bearer invalid_token" }
    assert_response :unauthorized
  end

  # Index tests
  test "index returns user projects excluding inbox" do
    get api_v1_projects_url, headers: @auth_header
    assert_response :success

    projects = response.parsed_body
    assert_kind_of Array, projects

    # Should not include inbox projects
    project_titles = projects.map { |p| p["title"] }
    assert_not_includes project_titles, "Inbox"
  end

  test "index returns project attributes" do
    get api_v1_projects_url, headers: @auth_header
    assert_response :success

    project = response.parsed_body.first
    assert project["id"].present?
    assert project["title"].present?
    assert project["created_at"].present?
    assert project["updated_at"].present?
  end

  # Show tests
  test "show returns project with task counts" do
    get api_v1_project_url(@project), headers: @auth_header
    assert_response :success

    project = response.parsed_body
    assert_equal @project.id, project["id"]
    assert_equal @project.title, project["title"]
    assert project.key?("task_count")
    assert project.key?("completed_task_count")
    assert project.key?("incomplete_task_count")
  end

  test "show returns not found for non-existent project" do
    get api_v1_project_url(id: 999999), headers: @auth_header
    assert_response :not_found
  end

  test "show returns not found for other users project" do
    other_project = projects(:two)
    get api_v1_project_url(other_project), headers: @auth_header
    assert_response :not_found
  end

  test "cannot access inbox project via show" do
    inbox = projects(:inbox_one)
    get api_v1_project_url(inbox), headers: @auth_header
    assert_response :not_found
  end

  # Create tests
  test "create creates new project" do
    assert_difference "Project.count", 1 do
      post api_v1_projects_url, params: { project: { title: "New Project", description: "Test desc" } }, headers: @auth_header
    end

    assert_response :created

    project = response.parsed_body
    assert_equal "New Project", project["title"]
    assert_equal "Test desc", project["description"]
  end

  test "create returns errors for invalid project" do
    post api_v1_projects_url, params: { project: { title: "" } }, headers: @auth_header
    assert_response :unprocessable_entity

    assert response.parsed_body["error"].present?
  end

  # ISO8601 timestamp tests
  test "timestamps are in ISO8601 format" do
    get api_v1_project_url(@project), headers: @auth_header
    assert_response :success

    project = response.parsed_body
    # ISO8601 format includes 'T' separator
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, project["created_at"])
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, project["updated_at"])
  end
end
