# frozen_string_literal: true

require "test_helper"

class MarketingTreeBuilderTest < ActiveSupport::TestCase
  class DummyController
    include MarketingTreeBuilder
    attr_reader :tree_builder_root_path
  end

  setup do
    @controller = DummyController.new
    @temp_dir = Dir.mktmpdir("marketing_tree_test")
  end

  teardown do
    FileUtils.remove_entry(@temp_dir) if Dir.exist?(@temp_dir)
  end

  # --- build_tree ---

  test "returns empty tree for non-existent directory" do
    tree = @controller.build_tree("/nonexistent/path")
    
    assert_equal "marketing", tree[:name]
    assert_equal :directory, tree[:type]
    assert_equal [], tree[:children]
  end

  test "builds tree with files and directories" do
    # Create: dir1/file1.txt, dir1/file2.md, dir2/
    FileUtils.mkdir_p(File.join(@temp_dir, "dir1"))
    File.write(File.join(@temp_dir, "dir1", "file1.txt"), "content")
    File.write(File.join(@temp_dir, "dir1", "file2.md"), "content")
    FileUtils.mkdir_p(File.join(@temp_dir, "dir2"))

    tree = @controller.build_tree(@temp_dir)

    assert_equal 2, tree[:children].length
    
    dir1 = tree[:children].find { |c| c[:name] == "dir1" }
    assert dir1
    assert_equal :directory, dir1[:type]
    assert_equal 2, dir1[:children].length
    
    dir2 = tree[:children].find { |c| c[:name] == "dir2" }
    assert dir2
    assert_equal :directory, dir2[:type]
    assert_equal [], dir2[:children]
  end

  test "filters by search query" do
    FileUtils.mkdir_p(File.join(@temp_dir, "folder1"))
    FileUtils.mkdir_p(File.join(@temp_dir, "folder2"))
    File.write(File.join(@temp_dir, "folder1", "match.txt"), "content")
    File.write(File.join(@temp_dir, "folder2", "other.txt"), "content")

    tree = @controller.build_tree(@temp_dir, "match")

    # Should only include folder1 which contains match.txt
    folder1 = tree[:children].find { |c| c[:name] == "folder1" }
    assert folder1, "Should find folder1 with match.txt"
    
    folder2 = tree[:children].find { |c| c[:name] == "folder2" }
    assert_nil folder2, "Should not include folder2 without match"
  end

  test "sorts directories before files" do
    FileUtils.mkdir_p(File.join(@temp_dir, "z_dir"))
    File.write(File.join(@temp_dir, "a_file.txt"), "content")

    tree = @controller.build_tree(@temp_dir)

    assert_equal "z_dir", tree[:children][0][:name]
    assert_equal "a_file.txt", tree[:children][1][:name]
  end

  test "adds extension to files" do
    File.write(File.join(@temp_dir, "doc.md"), "content")

    tree = @controller.build_tree(@temp_dir)

    file = tree[:children][0]
    assert_equal :file, file[:type]
    assert_equal ".md", file[:extension]
  end

  test "ignores hidden files starting with dot" do
    File.write(File.join(@temp_dir, "visible.txt"), "content")
    File.write(File.join(@temp_dir, ".hidden"), "content")

    tree = @controller.build_tree(@temp_dir)

    assert_equal 1, tree[:children].length
    assert_equal "visible.txt", tree[:children][0][:name]
  end
end
