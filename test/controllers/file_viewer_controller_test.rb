# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "fileutils"

class FileViewerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @created_files = []
  end

  teardown do
    @created_files.each do |path|
      FileUtils.rm_f(path)
    end
  end

  test "requires authentication" do
    sign_out

    get view_path(file: "README.md")
    assert_response :redirect
    assert_redirected_to new_session_path
  end

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

  test "download param forces attachment for text file" do
    relative = create_workspace_file("tmp/file-viewer-download-#{SecureRandom.hex(6)}.txt", "hello from viewer\n")

    get view_path(file: relative, download: 1)

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "filename=\"#{File.basename(relative)}\""
  end

  test "binary file is served as attachment" do
    relative = create_workspace_file("tmp/file-viewer-binary-#{SecureRandom.hex(6)}.png", "\x89PNG\r\n\x1A\nBINARY")

    get view_path(file: relative)

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "filename=\"#{File.basename(relative)}\""
  end

  private

  def create_workspace_file(relative, content)
    absolute = File.join(File.expand_path("~/.openclaw/workspace"), relative)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.binwrite(absolute, content)
    @created_files << absolute
    relative
  end
end
