require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
  end

  # === Auth bypass attempts ===

  test "API rejects forged session cookie" do
    cookies[:session_id] = "forged_value_12345"
    get api_v1_tasks_url
    assert_response :unauthorized
  end

  test "API rejects empty bearer token" do
    get api_v1_tasks_url, headers: { "Authorization" => "Bearer " }
    assert_response :unauthorized
  end

  test "API rejects token with wrong prefix format" do
    get api_v1_tasks_url, headers: { "Authorization" => "Token abc123" }
    assert_response :unauthorized
  end

  test "hooks reject empty token" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "hack" },
         headers: { "X-Hook-Token" => "" },
         as: :json
    assert_response :unauthorized
  end

  # === XSS in task fields ===

  test "task name with script tag is escaped in board view" do
    sign_in_as(@user)
    xss_name = '<script>alert("xss")</script>'
    Task.create!(name: xss_name, user: @user, board: @board, status: :inbox)
    get board_path(@board)
    assert_response :success
    assert_no_match(/<script>alert/, response.body)
  end

  # === Path traversal in view_file ===

  test "view_file rejects URL-encoded traversal" do
    sign_in_as(@user)
    get view_file_board_task_path(@board, @task, path: "..%2F..%2F..%2Fetc%2Fpasswd")
    assert_response :forbidden
  end

  # === Cross-user resource access ===

  test "user one cannot see user two board via direct URL" do
    sign_in_as(@user)
    other_board = boards(:two)
    begin
      get board_path(other_board)
      assert_response :not_found
    rescue ActiveRecord::RecordNotFound
      assert true
    end
  end

  test "user one cannot move user two task via API" do
    other_task = tasks(:two)
    auth = { "Authorization" => "Bearer test_token_one_abc123def456" }
    patch move_api_v1_task_url(other_task), params: { status: "done" }, headers: auth
    assert_response :not_found
    assert_not_equal "done", other_task.reload.status
  end

  # === Unauthenticated access ===

  test "unauthenticated user is redirected from all protected pages" do
    [dashboard_path, boards_path, search_path, nightbeat_path].each do |path|
      get path
      assert_response :redirect, "#{path} should redirect unauthenticated user"
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
