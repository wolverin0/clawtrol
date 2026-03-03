# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Boards::ProjectFilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    sign_in_as(@user)

    @tmp_dir = Dir.mktmpdir("board_project_files_test")
    @editable_file = File.join(@tmp_dir, "notes.md")
    File.write(@editable_file, "original")
    @readonly_file = File.join(@tmp_dir, "script.rb")
    File.write(@readonly_file, "puts 'hi'")

    @board.update!(project_path: @tmp_dir)
  end

  teardown do
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
  end

  test "index renders floating modal when requested from files turbo frame" do
    get board_project_files_path(@board), headers: { "Turbo-Frame" => "board_files_modal" }

    assert_response :success
    assert_includes response.body, 'data-controller="board-files-modal"'
    assert_includes response.body, 'data-testid="board-file-button"'
  end

  test "read returns content for valid path" do
    get read_board_project_files_path(@board), params: { path: @editable_file }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["success"]
    assert_equal "original", payload["content"]
    assert_equal true, payload["editable"]
  end

  test "read rejects traversal path" do
    get read_board_project_files_path(@board), params: { path: "/etc/passwd" }, as: :json

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_equal false, payload["success"]
    assert_match(/Ruta inválida|Invalid path/, payload["error"])
  end

  test "save persists editable file" do
    patch save_board_project_files_path(@board), params: { file_path: @editable_file, content: "updated" }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["success"]
    assert_equal "updated", File.read(@editable_file)
  end

  test "save rejects read-only extension" do
    patch save_board_project_files_path(@board), params: { file_path: @readonly_file, content: "changed" }, as: :json

    assert_response :forbidden
    payload = JSON.parse(response.body)
    assert_equal false, payload["success"]
    assert_match(/solo lectura/, payload["error"])
    assert_equal "puts 'hi'", File.read(@readonly_file)
  end
end
