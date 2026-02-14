# frozen_string_literal: true

require "test_helper"

class FileViewerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should redirect to login when not authenticated" do
    get view_path(file: "README.md")
    assert_response :redirect
    assert_redirected_to new_session_path
  end

  test "should require authentication to view files" do
    # Critical security test: unauthenticated users must NOT access workspace files
    get view_path(file: "TOOLS.md")
    assert_response :redirect
    assert_not_includes response.body, "credential", "Unauthenticated request must not leak file contents"
  end

end
