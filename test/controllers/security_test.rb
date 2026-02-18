# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # --- Auth bypass attempts ---

  test "all major routes require authentication" do
    unauthenticated_routes = [
      dashboard_path,
      search_path,
      nightbeat_path,
      boards_path,
      board_path(boards(:one))
    ]

    unauthenticated_routes.each do |path|
      get path
      assert_response :redirect, "Expected redirect for #{path} but got #{response.status}"
    end
  end

  # --- File viewer path traversal ---

  test "file viewer rejects path traversal with dot-dot" do
    sign_in_as(@user)
    get view_path(file: "../../../etc/passwd")
    assert_includes [403, 404], response.status
  end

  test "file viewer rejects absolute path" do
    sign_in_as(@user)
    get view_path(file: "/etc/passwd")
    assert_response :forbidden
  end

  test "file viewer rejects tilde home path" do
    sign_in_as(@user)
    get view_path(file: "~/.ssh/id_rsa")
    # The controller checks full.to_s.start_with?(WORKSPACE)
    assert_includes [403, 404], response.status
  end

  test "file viewer handles missing file gracefully" do
    sign_in_as(@user)
    get view_path(file: "nonexistent_file_12345.txt")
    # Controller may return 403 or 404 depending on path resolution logic
    assert_includes [403, 404], response.status
  end

  # --- XSS in markdown rendering ---

  test "markdown rendering strips script tags" do
    sign_in_as(@user)
    board = boards(:one)
    task = tasks(:one)
    task.update!(description: '<script>alert("xss")</script>')

    get board_task_path(board, task)
    assert_response :success
    # XSS payload should be escaped — literal <script>alert(...)</script> must NOT appear
    assert_no_match(%r{<script>alert\(}, response.body)
  end

  # --- API auth bypass ---

  test "API hooks reject missing token" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: tasks(:one).id, findings: "test" }
    assert_response :unauthorized
  end

  test "API hooks reject empty token" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: tasks(:one).id, version: "1", run_id: SecureRandom.uuid },
         headers: { "X-Hook-Token" => "" }
    assert_response :unauthorized
  end

  # --- Cross-user data isolation ---

  test "user cannot see other user's tasks in search" do
    sign_in_as(@user)
    get search_path, params: { q: "Test Task Two" }
    assert_response :success
    # The query term appears in the search input, but task should not appear in results
    assert_match "No results found", response.body
  end

  private
end
