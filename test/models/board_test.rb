# frozen_string_literal: true

require "test_helper"

class BoardTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
    @board = boards(:two)
  end

  # === Validations ===

  test "name is required" do
    board = Board.new(user: @user)
    assert_not board.valid?
    assert_includes board.errors[:name], "can't be blank"
  end

  test "name maximum length is 100" do
    board = Board.new(user: @user, name: "a" * 101)
    assert_not board.valid?
    assert board.errors[:name].any?
  end

  test "name is unique per user (case insensitive)" do
    board = Board.new(user: @user, name: @board.name.upcase, position: 0)
    assert_not board.valid?
    assert_includes board.errors[:name], "already exists"
  end

  test "different users can have same name" do
    other_user = users(:one)
    board = Board.new(user: other_user, name: @board.name, position: 0)
    assert board.valid?
  end

  test "position must be non-negative integer" do
    board = Board.new(user: @user, name: "Test", position: -1)
    assert_not board.valid?
    assert_includes board.errors[:position], "must be greater than or equal to 0"
  end

  test "position is set automatically on create" do
    board = Board.create!(user: @user, name: "Auto Position Board")
    assert board.position.positive?
  end

  test "color must be valid" do
    board = Board.new(user: @user, name: "Test", color: "invalid_color")
    assert_not board.valid?
    assert_includes board.errors[:color], "is not included in the list"
  end

  test "color can be nil" do
    board = Board.new(user: @user, name: "Test", color: nil)
    assert board.valid?
  end

  test "icon maximum length is 10" do
    board = Board.new(user: @user, name: "Test", icon: "a" * 11)
    assert_not board.valid?
    assert board.errors[:icon].any?
  end

  test "icon can be nil" do
    board = Board.new(user: @user, name: "Test", icon: nil)
    assert board.valid?
  end

  # === Associations ===

  test "belongs to user" do
    assert_equal @user, @board.user
  end

  test "has many tasks" do
    task = tasks(:one)
    task.update!(board: @board)
    assert_includes @board.tasks, task
  end

  test "tasks are destroyed with board" do
    board = Board.create!(user: @user, name: "Board With Tasks")
    task = Task.create!(user: @user, board: board, name: "Tmp task", status: "inbox")
    task_id = task.id

    board.destroy
    assert_not Task.exists?(task_id)
  end

  test "has many agent_personas" do
    assert_respond_to @board, :agent_personas
  end

  # === Auto-Claim Methods ===

  test "aggregator? returns is_aggregator?" do
    board = Board.new(is_aggregator: true)
    assert board.aggregator?

    board = Board.new(is_aggregator: false)
    assert_not board.aggregator?
  end

  test "auto_claim_enabled? returns correct value" do
    board = Board.new(auto_claim_enabled: true)
    assert board.auto_claim_enabled?

    board = Board.new(auto_claim_enabled: false)
    assert_not board.auto_claim_enabled?
  end

  test "can_auto_claim? returns false when disabled" do
    board = Board.new(auto_claim_enabled: false)
    assert_not board.can_auto_claim?
  end

  test "can_auto_claim? returns true when never claimed" do
    board = Board.new(auto_claim_enabled: true, last_auto_claim_at: nil)
    assert board.can_auto_claim?
  end

  test "can_auto_claim? respects rate limit" do
    board = Board.new(
      auto_claim_enabled: true,
      last_auto_claim_at: 30.seconds.ago
    )
    assert_not board.can_auto_claim?

    board = Board.new(
      auto_claim_enabled: true,
      last_auto_claim_at: 61.seconds.ago
    )
    assert board.can_auto_claim?
  end

  test "task_matches_auto_claim? returns true when no filters" do
    board = Board.new(auto_claim_enabled: true)
    task = Task.new
    assert board.task_matches_auto_claim?(task)
  end

  test "task_matches_auto_claim? with tags filter" do
    board = Board.new(
      auto_claim_enabled: true,
      auto_claim_tags: ["urgent", "bug"]
    )
    task = Task.new(tags: ["urgent"])
    assert board.task_matches_auto_claim?(task)

    task = Task.new(tags: ["feature"])
    assert_not board.task_matches_auto_claim?(task)
  end

  test "task_matches_auto_claim? with prefix filter" do
    board = Board.new(
      auto_claim_enabled: true,
      auto_claim_prefix: "BUG:"
    )
    task = Task.new(name: "BUG: Fix login")
    assert board.task_matches_auto_claim?(task)

    task = Task.new(name: "FEAT: Add login")
    assert_not board.task_matches_auto_claim?(task)
  end

  test "task_matches_auto_claim? with both filters (OR logic)" do
    board = Board.new(
      auto_claim_enabled: true,
      auto_claim_tags: ["urgent"],
      auto_claim_prefix: "BUG:"
    )
    # matches tags
    task1 = Task.new(name: "Fix", tags: ["urgent"])
    assert board.task_matches_auto_claim?(task1)

    # matches prefix
    task2 = Task.new(name: "BUG: Fix", tags: [])
    assert board.task_matches_auto_claim?(task2)

    # matches neither
    task3 = Task.new(name: "Feature", tags: ["feature"])
    assert_not board.task_matches_auto_claim?(task3)
  end

  test "record_auto_claim! updates timestamp" do
    board = Board.create!(user: @user, name: "Test Board")
    assert_nil board.last_auto_claim_at

    board.record_auto_claim!
    assert_not_nil board.last_auto_claim_at
  end

  # === Class Methods ===

  test "create_onboarding_for creates board with tasks" do
    user = users(:two)
    # Clean up any existing onboarding board
    Board.where(user: user, name: "Getting Started").destroy_all

    board = Board.create_onboarding_for(user)

    assert_equal "Getting Started", board.name
    assert_equal "🚀", board.icon
    assert_equal "blue", board.color
    assert_equal 7, board.tasks.count

    # Check specific tasks exist
    assert board.tasks.exists?(name: "👋 Welcome to ClawDeck!")
    assert board.tasks.exists?(name: "🎯 Try it yourself!")
    # Check status distribution
    assert_equal 6, board.tasks.where(status: "inbox").count
    assert_equal 1, board.tasks.where(status: "up_next").count
  end

  test "all_user_tasks returns tasks for user" do
    board = Board.new(user: @user)
    tasks = board.all_user_tasks
    assert tasks.where(user_id: @user.id).exists?
  end
end
