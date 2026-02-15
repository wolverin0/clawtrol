# frozen_string_literal: true

require "test_helper"

class SwarmIdeaTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @idea = SwarmIdea.new(
      title: "Optimize DB queries",
      description: "Find and fix N+1 queries",
      category: "code",
      suggested_model: "opus",
      estimated_minutes: 20,
      icon: "⚡",
      user: @user
    )
  end

  # --- Validations ---

  test "valid idea saves" do
    assert @idea.valid?
  end

  test "requires title" do
    @idea.title = nil
    assert_not @idea.valid?
    assert_includes @idea.errors[:title], "can't be blank"
  end

  test "estimated_minutes must be positive when present" do
    @idea.estimated_minutes = 0
    assert_not @idea.valid?

    @idea.estimated_minutes = -5
    assert_not @idea.valid?

    @idea.estimated_minutes = 1
    assert @idea.valid?
  end

  test "estimated_minutes allows nil" do
    @idea.estimated_minutes = nil
    assert @idea.valid?
  end

  test "estimated_minutes rejects values over 480" do
    @idea.estimated_minutes = 481
    assert_not @idea.valid?
    assert @idea.errors[:estimated_minutes].any?
  end

  test "title rejects strings over 500 chars" do
    @idea.title = "X" * 501
    assert_not @idea.valid?
    assert @idea.errors[:title].any?
  end

  test "description rejects strings over 10000 chars" do
    @idea.description = "X" * 10_001
    assert_not @idea.valid?
    assert @idea.errors[:description].any?
  end

  test "category validates against CATEGORIES" do
    @idea.category = "invalid_category"
    assert_not @idea.valid?
    assert @idea.errors[:category].any?
  end

  test "category allows blank" do
    @idea.category = ""
    assert @idea.valid?
  end

  test "suggested_model validates against MODELS" do
    @idea.suggested_model = "imaginary_model"
    assert_not @idea.valid?
    assert @idea.errors[:suggested_model].any?
  end

  test "suggested_model allows blank" do
    @idea.suggested_model = ""
    assert @idea.valid?
  end

  test "difficulty validates against allowed values" do
    @idea.difficulty = "impossible"
    assert_not @idea.valid?
    assert @idea.errors[:difficulty].any?

    @idea.difficulty = "hard"
    assert @idea.valid?
  end

  test "icon rejects long strings" do
    @idea.icon = "X" * 11
    assert_not @idea.valid?
    assert @idea.errors[:icon].any?
  end

  test "times_launched rejects negative values" do
    @idea.times_launched = -1
    assert_not @idea.valid?
    assert @idea.errors[:times_launched].any?
  end

  # --- Associations ---

  test "belongs to user" do
    assert_equal @user, @idea.user
  end

  test "board is optional" do
    @idea.board = nil
    assert @idea.valid?
  end

  # --- Scopes ---

  test "favorites scope returns only favorites" do
    favs = SwarmIdea.favorites
    assert_includes favs, swarm_ideas(:favorite_idea)
    assert_not_includes favs, swarm_ideas(:code_idea)
  end

  test "enabled scope filters disabled" do
    enabled = SwarmIdea.enabled
    assert_includes enabled, swarm_ideas(:code_idea)
    assert_not_includes enabled, swarm_ideas(:disabled_idea)
  end

  test "recently_launched returns ideas with launch history" do
    recent = SwarmIdea.recently_launched
    assert_includes recent, swarm_ideas(:favorite_idea)
    assert_not_includes recent, swarm_ideas(:code_idea)
  end

  test "by_category filters by category" do
    code = SwarmIdea.by_category("code")
    assert_includes code, swarm_ideas(:code_idea)
    assert_not_includes code, swarm_ideas(:favorite_idea)
  end

  test "by_category returns all when nil" do
    all = SwarmIdea.by_category(nil)
    assert_includes all, swarm_ideas(:code_idea)
    assert_includes all, swarm_ideas(:favorite_idea)
  end

  # --- Instance Methods ---

  test "launched_today? returns false if never launched" do
    assert_not @idea.launched_today?
  end

  test "launched_today? returns true if launched today" do
    @idea.last_launched_at = 1.hour.ago
    assert @idea.launched_today?
  end

  test "launched_today? returns false if launched yesterday" do
    @idea.last_launched_at = 1.day.ago
    assert_not @idea.launched_today?
  end

  test "launch_count_display returns nil when never launched" do
    @idea.times_launched = 0
    assert_nil @idea.launch_count_display
  end

  test "launch_count_display returns formatted count" do
    @idea.times_launched = 3
    assert_equal "×3", @idea.launch_count_display
  end

  # --- Fixture smoke ---

  test "fixtures load correctly" do
    assert swarm_ideas(:code_idea).enabled?
    assert swarm_ideas(:favorite_idea).favorite?
    assert_not swarm_ideas(:disabled_idea).enabled?
  end
end
