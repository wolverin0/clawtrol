# frozen_string_literal: true

require "test_helper"

# Integration tests for view_file security (Boards::TasksController#view_file)
# Tests the complete request flow to ensure security controls work end-to-end
class ViewFileSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    sign_in_as(@user)
  end

  # === SECURITY: Absolute paths must be rejected ===

  test "absolute path /etc/passwd is forbidden" do
    get view_file_board_task_path(@board, @task, path: "/etc/passwd")
    assert_response :forbidden
    assert_not_includes response.body, "root:", "Must not leak file contents"
  end

  test "absolute path to home directory is forbidden" do
    get view_file_board_task_path(@board, @task, path: "/home/ggorbalan/.bashrc")
    assert_response :forbidden
  end

  test "absolute path to TOOLS.md is forbidden" do
    get view_file_board_task_path(@board, @task, path: "/home/ggorbalan/.openclaw/workspace/TOOLS.md")
    assert_response :forbidden
    assert_not_includes response.body, "credential", "Must not leak credentials"
    assert_not_includes response.body, "API Key", "Must not leak API keys"
  end

  # === SECURITY: Tilde paths must be rejected ===

  test "tilde path ~/.openclaw/workspace/TOOLS.md is forbidden" do
    get view_file_board_task_path(@board, @task, path: "~/.openclaw/workspace/TOOLS.md")
    assert_response :forbidden
    assert_not_includes response.body, "credential", "Must not leak credentials"
  end

  test "tilde path ~/.ssh/id_rsa is forbidden" do
    get view_file_board_task_path(@board, @task, path: "~/.ssh/id_rsa")
    assert_response :forbidden
  end

  test "tilde path ~/any_file is forbidden" do
    get view_file_board_task_path(@board, @task, path: "~/README.md")
    assert_response :forbidden
  end

  # === SECURITY: Dotfiles/dotdirs must be rejected ===

  test "dotfile .env is forbidden" do
    get view_file_board_task_path(@board, @task, path: ".env")
    assert_response :forbidden
  end

  test "dotdir .ssh/id_rsa is forbidden" do
    get view_file_board_task_path(@board, @task, path: ".ssh/id_rsa")
    assert_response :forbidden
  end

  test "dotdir .openclaw/workspace/TOOLS.md is forbidden" do
    get view_file_board_task_path(@board, @task, path: ".openclaw/workspace/TOOLS.md")
    assert_response :forbidden
  end

  test "nested dotdir config/.secrets/key is forbidden" do
    get view_file_board_task_path(@board, @task, path: "config/.secrets/api_key")
    assert_response :forbidden
  end

  # === SECURITY: Path traversal must be rejected ===

  test "path traversal ../../../etc/passwd is forbidden" do
    get view_file_board_task_path(@board, @task, path: "../../../etc/passwd")
    assert_response :forbidden
  end

  test "path traversal to TOOLS.md is forbidden" do
    get view_file_board_task_path(@board, @task, path: "app/../../../.openclaw/workspace/TOOLS.md")
    assert_response :forbidden
  end

  test "double-encoded path traversal is forbidden" do
    get view_file_board_task_path(@board, @task, path: "..%252F..%252Fetc%252Fpasswd")
    assert_response :forbidden
  end

  # === VALID: Relative paths within project should work ===

  test "valid relative path README.md succeeds if file exists" do
    # Create a test file in the project
    test_path = Rails.root.join("README.md")
    if File.exist?(test_path)
      get view_file_board_task_path(@board, @task, path: "README.md")
      # Should be success or not found, but NOT forbidden
      assert_includes [200, 404], response.status, "Valid relative paths should not be forbidden"
    else
      skip "README.md not present in project"
    end
  end

  # === EDGE CASES ===

  test "blank path returns bad request" do
    get view_file_board_task_path(@board, @task, path: "")
    assert_response :bad_request
  end

  test "missing path returns bad request" do
    get view_file_board_task_path(@board, @task)
    assert_response :bad_request
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
    follow_redirect! if response.redirect?
  end
end
