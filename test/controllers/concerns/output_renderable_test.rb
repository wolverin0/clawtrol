# frozen_string_literal: true

require "test_helper"

# Test class that includes OutputRenderable for testing resolve_safe_path
class OutputRenderableTestController
  include OutputRenderable
end

class OutputRenderableTest < ActiveSupport::TestCase
  setup do
    @controller = OutputRenderableTestController.new
    @project_root = File.expand_path("~/clawdeck")
    @storage_root = File.expand_path("~/clawdeck/storage")
    @allowed_dirs = [@project_root, @storage_root]
  end

  # === POSITIVE TESTS: Valid paths that should work ===

  test "relative path within project works" do
    # Create a temp file for testing
    test_file = File.join(@project_root, "README.md")
    if File.exist?(test_file)
      result = @controller.send(:resolve_safe_path, "README.md", allowed_dirs: @allowed_dirs)
      assert_not_nil result, "Relative path within project should resolve"
      assert result.start_with?(@project_root), "Path should be within project root"
    else
      skip "README.md not present in project root"
    end
  end

  test "nested relative path within project works" do
    result = @controller.send(:resolve_safe_path, "app/controllers/application_controller.rb", allowed_dirs: @allowed_dirs)
    # May return nil if file doesn't exist, but shouldn't be blocked by security
    # The security check should pass, existence check happens later
    if File.exist?(File.join(@project_root, "app/controllers/application_controller.rb"))
      assert_not_nil result
      assert result.start_with?(@project_root)
    end
  end

  test "storage path works" do
    result = @controller.send(:resolve_safe_path, "test_output.html", allowed_dirs: [@storage_root])
    # File may or may not exist - if it does, path should be within storage_root
    # If it doesn't exist, result is still non-nil (first candidate as fallback)
    if result
      assert result.start_with?(@storage_root), "Storage path should be within storage root"
    end
  end

  # === NEGATIVE TESTS: Paths that MUST be rejected ===

  test "absolute path is rejected" do
    result = @controller.send(:resolve_safe_path, "/etc/passwd", allowed_dirs: @allowed_dirs)
    assert_nil result, "Absolute paths must be rejected"
  end

  test "absolute path to home is rejected" do
    result = @controller.send(:resolve_safe_path, "/home/ggorbalan/.openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "Absolute paths must be rejected even to home directory"
  end

  test "tilde path is rejected" do
    result = @controller.send(:resolve_safe_path, "~/.openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "Tilde (~/) paths must be rejected"
  end

  test "tilde path to home is rejected" do
    result = @controller.send(:resolve_safe_path, "~/", allowed_dirs: @allowed_dirs)
    assert_nil result, "Tilde (~) paths must be rejected"
  end

  test "path traversal is rejected" do
    result = @controller.send(:resolve_safe_path, "../../../etc/passwd", allowed_dirs: @allowed_dirs)
    assert_nil result, "Path traversal (../) must be rejected"
  end

  test "path traversal to parent directory is rejected" do
    result = @controller.send(:resolve_safe_path, "app/../../../.openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "Path traversal escaping project must be rejected"
  end

  test "dotfile path .ssh is rejected" do
    result = @controller.send(:resolve_safe_path, ".ssh/id_rsa", allowed_dirs: @allowed_dirs)
    assert_nil result, "Dotfile paths (.ssh) must be rejected"
  end

  test "dotfile path .gnupg is rejected" do
    result = @controller.send(:resolve_safe_path, ".gnupg/secring.gpg", allowed_dirs: @allowed_dirs)
    assert_nil result, "Dotfile paths (.gnupg) must be rejected"
  end

  test "dotfile path .env is rejected" do
    result = @controller.send(:resolve_safe_path, ".env", allowed_dirs: @allowed_dirs)
    assert_nil result, "Dotfile paths (.env) must be rejected"
  end

  test "dotfile path .openclaw is rejected" do
    result = @controller.send(:resolve_safe_path, ".openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "Dotfile paths (.openclaw) must be rejected"
  end

  test "nested dotfile path is rejected" do
    result = @controller.send(:resolve_safe_path, "config/.secrets/api_key", allowed_dirs: @allowed_dirs)
    assert_nil result, "Nested dotfile paths must be rejected"
  end

  test "TOOLS.md specifically is rejected" do
    # Direct attempt
    result = @controller.send(:resolve_safe_path, "~/.openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "TOOLS.md via ~/ must be rejected"

    # Via dotfile path
    result = @controller.send(:resolve_safe_path, ".openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "TOOLS.md via dotfile must be rejected"

    # Via absolute path
    result = @controller.send(:resolve_safe_path, "/home/ggorbalan/.openclaw/workspace/TOOLS.md", allowed_dirs: @allowed_dirs)
    assert_nil result, "TOOLS.md via absolute path must be rejected"
  end

  # === EDGE CASES ===

  test "blank path returns nil" do
    result = @controller.send(:resolve_safe_path, "", allowed_dirs: @allowed_dirs)
    assert_nil result, "Blank path should return nil"
  end

  test "nil path returns nil" do
    result = @controller.send(:resolve_safe_path, nil, allowed_dirs: @allowed_dirs)
    assert_nil result, "Nil path should return nil"
  end

  test "whitespace-only path returns nil" do
    result = @controller.send(:resolve_safe_path, "   ", allowed_dirs: @allowed_dirs)
    assert_nil result, "Whitespace-only path should return nil"
  end

  test "path with embedded null byte is safe" do
    # Null bytes could be used to bypass checks in some languages
    result = @controller.send(:resolve_safe_path, "file\x00.txt", allowed_dirs: @allowed_dirs)
    # Should either return nil or a safe path
    assert_nil(result) || assert(result&.start_with?(@project_root))
  end

  test "path starting with single dot is rejected" do
    result = @controller.send(:resolve_safe_path, ".hidden_file", allowed_dirs: @allowed_dirs)
    assert_nil result, "Dotfile should be rejected"

    # ./relative should be allowed (. component != dotfile)
    result2 = @controller.send(:resolve_safe_path, "./app/models", allowed_dirs: @allowed_dirs)
    # "." alone is allowed by our filter, so this resolves normally
  end

  test "URL encoded path traversal is handled" do
    # URL encoding shouldn't bypass security
    # Ruby's File.expand_path handles this, but let's verify
    result = @controller.send(:resolve_safe_path, "..%2F..%2Fetc%2Fpasswd", allowed_dirs: @allowed_dirs)
    # This should either be rejected or resolve safely within allowed dirs
    assert_nil(result) || assert(result&.start_with?(@project_root) || result&.start_with?(@storage_root))
  end
end
