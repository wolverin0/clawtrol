# frozen_string_literal: true

require "test_helper"

class BoardTest < ActiveSupport::TestCase
  setup do
    @board = boards(:one)
    @user = users(:one)
  end

  # --- Validations ---

  test "valid board" do
    assert @board.valid?
  end

  test "requires name" do
    @board.name = nil
    assert_not @board.valid?
    assert_includes @board.errors[:name], "can't be blank"
  end

  test "requires position" do
    @board.position = nil
    assert_not @board.valid?
    assert_includes @board.errors[:position], "can't be blank"
  end

  test "rejects negative position" do
    @board.position = -1
    assert_not @board.valid?
    assert @board.errors[:position].any?
  end

  test "rejects name longer than 100 chars" do
    @board.name = "x" * 101
    assert_not @board.valid?
    assert @board.errors[:name].any?
  end

  test "rejects duplicate name for same user (case insensitive)" do
    existing = @user.boards.create!(name: "My Board")
    dupe = @user.boards.new(name: "my board", position: 99)
    assert_not dupe.valid?
    assert_includes dupe.errors[:name], "already exists"
  ensure
    existing&.destroy
  end

  test "allows same name for different users" do
    other_user = users(:default)
    @board.name = "Shared Name"
    @board.save!
    other_board = other_user.boards.new(name: "Shared Name", position: 1)
    assert other_board.valid?
  end

  test "rejects invalid color" do
    @board.color = "neon_banana"
    assert_not @board.valid?
    assert @board.errors[:color].any?
  end

  test "accepts valid color" do
    @board.color = "blue"
    assert @board.valid?
  end

  test "rejects icon longer than 10 chars" do
    @board.icon = "x" * 11
    assert_not @board.valid?
    assert @board.errors[:icon].any?
  end

  # --- Associations ---

  test "belongs to user" do
    assert_equal @user, @board.user
  end

  test "has many tasks" do
    assert_respond_to @board, :tasks
  end

  test "destroys tasks on destroy" do
    task = @board.tasks.create!(name: "temp", user: @user)
    assert_difference "Task.count", -1 do
      @board.tasks.where(id: task.id).first.destroy
    end
  end

  # --- Auto-claim ---

  test "can_auto_claim? returns false when disabled" do
    @board.auto_claim_enabled = false
    assert_not @board.can_auto_claim?
  end

  test "can_auto_claim? returns true when enabled and no prior claim" do
    @board.auto_claim_enabled = true
    @board.last_auto_claim_at = nil
    assert @board.can_auto_claim?
  end

  test "can_auto_claim? respects rate limit" do
    @board.auto_claim_enabled = true
    @board.last_auto_claim_at = 30.seconds.ago
    assert_not @board.can_auto_claim?
  end

  test "can_auto_claim? allows after rate limit window" do
    @board.auto_claim_enabled = true
    @board.last_auto_claim_at = 2.minutes.ago
    assert @board.can_auto_claim?
  end

  # --- task_matches_auto_claim? ---

  test "matches all tasks when no filters set" do
    @board.auto_claim_enabled = true
    @board.auto_claim_prefix = nil
    @board.auto_claim_tags = nil
    task = Task.new(name: "anything", tags: [])
    assert @board.task_matches_auto_claim?(task)
  end

  test "matches by prefix" do
    @board.auto_claim_enabled = true
    @board.auto_claim_prefix = "[BUG]"
    @board.auto_claim_tags = nil
    matching = Task.new(name: "[BUG] something broke", tags: [])
    non_matching = Task.new(name: "feature request", tags: [])
    assert @board.task_matches_auto_claim?(matching)
    assert_not @board.task_matches_auto_claim?(non_matching)
  end

  test "returns false when auto_claim disabled" do
    @board.auto_claim_enabled = false
    task = Task.new(name: "anything", tags: [])
    assert_not @board.task_matches_auto_claim?(task)
  end

  # --- Aggregator ---

  test "aggregator? delegates to is_aggregator" do
    @board.is_aggregator = true
    assert @board.aggregator?
    @board.is_aggregator = false
    assert_not @board.aggregator?
  end

  # --- Position auto-set ---

  test "auto-sets position on create when not provided" do
    board = @user.boards.create!(name: "New Board")
    assert board.position > 0
  end

  # --- COLORS and ICONS constants ---

  test "COLORS is a frozen array of strings" do
    assert Board::COLORS.frozen?
    assert_includes Board::COLORS, "gray"
    assert_includes Board::COLORS, "blue"
  end

  test "DEFAULT_ICONS is a frozen array" do
    assert Board::DEFAULT_ICONS.frozen?
    assert_includes Board::DEFAULT_ICONS, "📋"
  end
end
