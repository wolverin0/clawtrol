# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class SoulEditorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    sign_in_as(@user)

    @tmp_workspace = Dir.mktmpdir("soul-workspace")
    @tmp_storage = Dir.mktmpdir("soul-history")

    File.write(File.join(@tmp_workspace, "SOUL.md"), "Original soul")
    File.write(File.join(@tmp_workspace, "IDENTITY.md"), "Identity")
    File.write(File.join(@tmp_workspace, "USER.md"), "User")
    File.write(File.join(@tmp_workspace, "AGENTS.md"), "Agents")

    swap_constant(SoulEditorController, :WORKSPACE, @tmp_workspace)
    swap_constant(SoulEditorController, :HISTORY_DIR, Pathname.new(@tmp_storage))
  end

  teardown do
    sign_out
    Dir.exist?(@tmp_workspace) && FileUtils.remove_entry(@tmp_workspace)
    Dir.exist?(@tmp_storage) && FileUtils.remove_entry(@tmp_storage)
  end

  test "show renders page" do
    get soul_editor_path
    assert_response :success
    assert_includes @response.body, "Soul Editor"
  end

  test "show json returns file content" do
    get soul_editor_path(file: "SOUL.md"), as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_equal "SOUL.md", body["file"]
    assert_equal "Original soul", body["content"]
  end

  test "update writes file and pushes history" do
    patch soul_editor_path, params: { file: "SOUL.md", content: "Updated soul" }, as: :json
    assert_response :success

    assert_equal "Updated soul", File.read(File.join(@tmp_workspace, "SOUL.md"))

    history_path = File.join(@tmp_storage, "SOUL.md-history.json")
    assert File.exist?(history_path)

    versions = JSON.parse(File.read(history_path))
    assert_equal "Original soul", versions.last["content"]
  end

  test "history returns versions" do
    patch soul_editor_path, params: { file: "SOUL.md", content: "v2" }, as: :json

    get soul_editor_history_path(file: "SOUL.md"), as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_equal "SOUL.md", body["file"]
    assert body["history"].is_a?(Array)
    assert_equal "Original soul", body["history"].last["content"]
  end

  test "revert restores selected version" do
    patch soul_editor_path, params: { file: "SOUL.md", content: "v2" }, as: :json

    history = JSON.parse(File.read(File.join(@tmp_storage, "SOUL.md-history.json")))
    timestamp = history.last["timestamp"]

    post soul_editor_revert_path, params: { file: "SOUL.md", timestamp: timestamp }, as: :json
    assert_response :success

    assert_equal "Original soul", File.read(File.join(@tmp_workspace, "SOUL.md"))
  end

  test "templates are available for soul only" do
    get soul_editor_templates_path(file: "SOUL.md"), as: :json
    assert_response :success
    soul_templates = JSON.parse(response.body)["templates"]
    assert_equal 6, soul_templates.length

    get soul_editor_templates_path(file: "USER.md"), as: :json
    assert_response :success
    other_templates = JSON.parse(response.body)["templates"]
    assert_equal [], other_templates
  end

  test "invalid file returns error" do
    get soul_editor_path(file: "../../etc/passwd"), as: :json
    assert_response :unprocessable_entity
  end

  private

  def swap_constant(klass, name, value)
    klass.send(:remove_const, name) if klass.const_defined?(name, false)
    klass.const_set(name, value)
  end
end
