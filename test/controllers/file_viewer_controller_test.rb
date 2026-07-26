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

  test "rejects oversized file updates" do
    relative = "tmp/file-viewer-update-#{SecureRandom.hex(6)}.txt"
    oversized_content = "a" * (FileViewerController::MAX_FILE_SIZE + 1)

    put view_path(file: relative),
        params: { file: relative, content: oversized_content },
        as: :json

    assert_response :content_too_large
    assert_match(/Content too large/, response.parsed_body["error"])
  end

  # --- Logical root prefixes ---

  test "openclaw/<path> resolves to OpenClaw workspace" do
    relative = "tmp/file-viewer-openclaw-#{SecureRandom.hex(6)}.md"
    create_workspace_file(relative, "# hello openclaw\n")

    get view_path(file: "openclaw/#{relative}")

    assert_response :success
    assert_match(/hello openclaw/, response.body)
  end

  test "bare path still resolves to OpenClaw workspace for back compat" do
    relative = create_workspace_file("tmp/file-viewer-bare-#{SecureRandom.hex(6)}.md", "# bare path works\n")

    get view_path(file: relative)

    assert_response :success
    assert_match(/bare path works/, response.body)
  end

  test "hermes/<path> resolves under HERMES_VIEWER_DIR when configured" do
    tmpdir = Dir.mktmpdir("hermes-viewer")
    rel = "research/hermes-note-#{SecureRandom.hex(4)}.md"
    abs = File.join(tmpdir, rel)
    FileUtils.mkdir_p(File.dirname(abs))
    File.write(abs, "# hermes artifact\n")

    saved = ENV["HERMES_VIEWER_DIR"]
    ENV["HERMES_VIEWER_DIR"] = tmpdir
    with_reloaded_viewer_constants do
      get view_path(file: "hermes/#{rel}")
      assert_response :success
      assert_match(/hermes artifact/, response.body)
    end
  ensure
    ENV["HERMES_VIEWER_DIR"] = saved
    FileUtils.remove_entry(tmpdir) if tmpdir && File.directory?(tmpdir)
  end

  test "hermes/<path> defaults to dedicated ~/.hermes/artifacts viewer root" do
    rel = "tmp/file-viewer-hermes-default-#{SecureRandom.hex(4)}.md"
    abs = File.join(File.expand_path("~/.hermes/artifacts"), rel)
    FileUtils.mkdir_p(File.dirname(abs))
    File.write(abs, "# hermes default artifact\n")
    @created_files << abs

    saved_viewer = ENV["HERMES_VIEWER_DIR"]
    saved_workspace = ENV["HERMES_WORKSPACE_DIR"]
    ENV.delete("HERMES_VIEWER_DIR")
    ENV.delete("HERMES_WORKSPACE_DIR")
    with_reloaded_viewer_constants do
      get view_path(file: "hermes/#{rel}")
      assert_response :success
      assert_match(/hermes default artifact/, response.body)
    end
  ensure
    ENV["HERMES_VIEWER_DIR"] = saved_viewer
    ENV["HERMES_WORKSPACE_DIR"] = saved_workspace
  end

  test "hermes/<path> does not expose files from raw hermes home" do
    rel = "config-#{SecureRandom.hex(4)}.yml"
    abs = File.join(File.expand_path("~/.hermes"), rel)
    FileUtils.mkdir_p(File.dirname(abs))
    File.write(abs, "token: should-not-render\n")
    @created_files << abs

    saved_viewer = ENV["HERMES_VIEWER_DIR"]
    saved_workspace = ENV["HERMES_WORKSPACE_DIR"]
    ENV.delete("HERMES_VIEWER_DIR")
    ENV.delete("HERMES_WORKSPACE_DIR")
    with_reloaded_viewer_constants do
      get view_path(file: "hermes/#{rel}")
      assert_response :forbidden
      assert_no_match(/should-not-render/, response.body)
    end
  ensure
    ENV["HERMES_VIEWER_DIR"] = saved_viewer
    ENV["HERMES_WORKSPACE_DIR"] = saved_workspace
  end

  test "update rejects writes to hermes logical root" do
    tmpdir = Dir.mktmpdir("hermes-viewer")
    rel = "research/hermes-note-#{SecureRandom.hex(4)}.md"
    abs = File.join(tmpdir, rel)
    FileUtils.mkdir_p(File.dirname(abs))
    File.write(abs, "original\n")

    saved = ENV["HERMES_VIEWER_DIR"]
    ENV["HERMES_VIEWER_DIR"] = tmpdir
    with_reloaded_viewer_constants do
      put view_path(file: "hermes/#{rel}"), params: { file: "hermes/#{rel}", content: "changed\n" }, as: :json
      assert_response :forbidden
      assert_equal "original\n", File.read(abs)
    end
  ensure
    ENV["HERMES_VIEWER_DIR"] = saved
    FileUtils.remove_entry(tmpdir) if tmpdir && File.directory?(tmpdir)
  end

  test "logical openclaw prefix still rejects traversal" do
    get view_path(file: "openclaw/../../etc/passwd")
    assert_response :forbidden
  end

  private

  def create_workspace_file(relative, content)
    absolute = File.join(File.expand_path("~/.openclaw/workspace"), relative)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.binwrite(absolute, content)
    @created_files << absolute
    relative
  end

  # Reloads the FileViewerController so frozen constants pick up env changes.
  # Constants are frozen at load time; for tests that need to flip
  # HERMES_WORKSPACE_DIR, we have to reload the source file.
  def with_reloaded_viewer_constants
    Object.send(:remove_const, :FileViewerController) if Object.const_defined?(:FileViewerController)
    load Rails.root.join("app/controllers/file_viewer_controller.rb")
    yield
  ensure
    Object.send(:remove_const, :FileViewerController) if Object.const_defined?(:FileViewerController)
    load Rails.root.join("app/controllers/file_viewer_controller.rb")
  end
end
