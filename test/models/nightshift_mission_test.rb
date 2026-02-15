# frozen_string_literal: true

require "test_helper"

class NightshiftMissionTest < ActiveSupport::TestCase
  def setup
    @user = users(:default)
    @mission = NightshiftMission.new(
      name: "Security Audit",
      description: "Run security checks",
      frequency: "always",
      category: "security",
      model: "gemini",
      estimated_minutes: 30,
      position: 0,
      icon: "🔒",
      user: @user
    )
  end

  # --- Validations ---

  test "valid mission saves" do
    assert @mission.valid?
  end

  test "requires name" do
    @mission.name = nil
    assert_not @mission.valid?
    assert_includes @mission.errors[:name], "can't be blank"
  end

  test "name cannot exceed 255 characters" do
    @mission.name = "a" * 256
    assert_not @mission.valid?
  end

  test "description cannot exceed 10000 characters" do
    @mission.description = "a" * 10_001
    assert_not @mission.valid?
  end

  test "frequency must be in FREQUENCIES" do
    @mission.frequency = "invalid"
    assert_not @mission.valid?
    assert_includes @mission.errors[:frequency].join, "is not included"
  end

  test "category must be in CATEGORIES" do
    @mission.category = "invalid"
    assert_not @mission.valid?
    assert_includes @mission.errors[:category].join, "is not included"
  end

  test "model allows blank" do
    @mission.model = ""
    assert @mission.valid?
  end

  test "model must be in VALID_MODELS when present" do
    @mission.model = "gpt99"
    assert_not @mission.valid?
  end

  test "estimated_minutes must be positive integer" do
    @mission.estimated_minutes = 0
    assert_not @mission.valid?

    @mission.estimated_minutes = -5
    assert_not @mission.valid?

    @mission.estimated_minutes = 481
    assert_not @mission.valid?

    @mission.estimated_minutes = 480
    assert @mission.valid?
  end

  test "position must be non-negative integer" do
    @mission.position = -1
    assert_not @mission.valid?
  end

  test "days_of_week must be valid array of 1-7" do
    @mission.days_of_week = [1, 3, 5]
    assert @mission.valid?

    @mission.days_of_week = [0, 8]
    assert_not @mission.valid?

    @mission.days_of_week = "not_array"
    assert_not @mission.valid?
  end

  test "days_of_week allows blank" do
    @mission.days_of_week = []
    assert @mission.valid?

    @mission.days_of_week = nil
    assert @mission.valid?
  end

  # --- Scopes ---

  test "enabled scope filters by enabled" do
    @mission.save!
    disabled = NightshiftMission.create!(name: "Disabled", frequency: "manual", category: "general", enabled: false, user: @user)

    enabled = NightshiftMission.enabled
    assert_includes enabled, @mission
    assert_not_includes enabled, disabled
  end

  # --- due_tonight? ---

  test "always frequency is always due" do
    @mission.frequency = "always"
    assert @mission.due_tonight?
  end

  test "manual frequency is never due" do
    @mission.frequency = "manual"
    assert_not @mission.due_tonight?
  end

  test "one_time is due only if never run" do
    @mission.frequency = "one_time"
    @mission.last_run_at = nil
    assert @mission.due_tonight?

    @mission.last_run_at = 1.day.ago
    assert_not @mission.due_tonight?
  end

  test "disabled mission is never due" do
    @mission.frequency = "always"
    @mission.enabled = false
    assert_not @mission.due_tonight?
  end

  # --- to_mission_hash ---

  test "to_mission_hash returns expected keys" do
    @mission.save!
    hash = @mission.to_mission_hash
    assert_equal @mission.id, hash[:id]
    assert_equal "Security Audit", hash[:title]
    assert_equal "gemini", hash[:model]
    assert_equal "security", hash[:category]
  end
end
