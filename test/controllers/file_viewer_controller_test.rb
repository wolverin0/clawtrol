# frozen_string_literal: true

require "test_helper"

class FileViewerControllerTest < ActionDispatch::IntegrationTest
  # FileViewer allows unauthenticated access by design (public file viewer).
  # Security is enforced by path validation, not authentication.

  test "returns 403 for nonexistent files" do
    get view_path(file: "nonexistent_file_that_does_not_exist.md")
    assert_response :forbidden
  end

  test "blocks directory traversal attempts" do
    get view_path(file: "../../../etc/passwd")
    assert_response :forbidden
  end

  test "blocks dotfiles" do
    get view_path(file: ".env")
    assert_response :forbidden
  end

  test "blocks null bytes in path" do
    get view_path(file: "README.md\x00.txt")
    assert_response :forbidden
  end

  test "blocks symlink escape attempts" do
    get view_path(file: "../../.ssh/id_rsa")
    assert_response :forbidden
  end
end
