# frozen_string_literal: true

require "test_helper"

class BoardFileRefTest < ActiveSupport::TestCase
  setup do
    @board = boards(:one)
  end

  test "valid reference under allowed viewer directory" do
    ref = BoardFileRef.new(board: @board, path: "clawdeck/README.md", category: "docs", position: 0)
    assert ref.valid?
  end

  test "rejects traversal path" do
    ref = BoardFileRef.new(board: @board, path: "../.env", category: "general", position: 0)
    assert_not ref.valid?
    assert ref.errors[:path].any?
  end

  test "rejects dotfiles" do
    ref = BoardFileRef.new(board: @board, path: "clawdeck/.env", category: "general", position: 0)
    assert_not ref.valid?
    assert_includes ref.errors[:path], "cannot include dotfiles or dot-directories"
  end
end
