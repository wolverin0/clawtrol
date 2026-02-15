# frozen_string_literal: true

require "test_helper"

class NightshiftSelectionTest < ActiveSupport::TestCase
  def setup
    @user = users(:default)
    @mission = NightshiftMission.create!(
      name: "Test Mission",
      frequency: "always",
      category: "general",
      user: @user
    )
    @selection = NightshiftSelection.new(
      nightshift_mission: @mission,
      title: "Tonight's run",
      scheduled_date: Date.current,
      status: "pending"
    )
  end

  # --- Validations ---

  test "valid selection saves" do
    assert @selection.valid?
  end

  test "requires title" do
    @selection.title = nil
    assert_not @selection.valid?
    assert_includes @selection.errors[:title], "can't be blank"
  end

  test "title cannot exceed 500 characters" do
    @selection.title = "a" * 501
    assert_not @selection.valid?
  end

  test "requires scheduled_date" do
    @selection.scheduled_date = nil
    assert_not @selection.valid?
  end

  test "status must be valid" do
    @selection.status = "invalid"
    assert_not @selection.valid?
  end

  test "all valid statuses accepted" do
    NightshiftSelection::STATUSES.each do |s|
      @selection.status = s
      # Clear completed_at for non-terminal statuses
      @selection.completed_at = nil unless %w[completed failed].include?(s)
      assert @selection.valid?, "Status '#{s}' should be valid"
    end
  end

  test "result cannot exceed 100000 characters" do
    @selection.result = "a" * 100_001
    assert_not @selection.valid?
  end

  test "uniqueness of mission per scheduled_date" do
    @selection.save!
    dup = NightshiftSelection.new(
      nightshift_mission: @mission,
      title: "Duplicate",
      scheduled_date: Date.current,
      status: "pending"
    )
    assert_not dup.valid?
    assert_includes dup.errors[:nightshift_mission_id].join, "already has a selection"
  end

  test "same mission can have selections on different dates" do
    @selection.save!
    tomorrow = NightshiftSelection.new(
      nightshift_mission: @mission,
      title: "Tomorrow's run",
      scheduled_date: Date.current + 1,
      status: "pending"
    )
    assert tomorrow.valid?
  end

  test "completed_at requires terminal status" do
    @selection.status = "pending"
    @selection.completed_at = Time.current
    assert_not @selection.valid?
    assert_includes @selection.errors[:completed_at].join, "can only be set when status is completed or failed"
  end

  test "completed_at valid with completed status" do
    @selection.status = "completed"
    @selection.completed_at = Time.current
    assert @selection.valid?
  end

  test "completed_at valid with failed status" do
    @selection.status = "failed"
    @selection.completed_at = Time.current
    assert @selection.valid?
  end

  test "launched_at cannot be in the future" do
    @selection.launched_at = 1.hour.from_now
    assert_not @selection.valid?
    assert_includes @selection.errors[:launched_at].join, "cannot be in the future"
  end

  test "launched_at allows current time" do
    @selection.launched_at = Time.current
    assert @selection.valid?
  end

  # --- Scopes ---

  test "for_tonight returns today's selections" do
    @selection.save!
    yesterday = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Yesterday",
      scheduled_date: Date.current - 1,
      status: "completed",
      completed_at: 1.day.ago
    )

    tonight = NightshiftSelection.for_tonight
    assert_includes tonight, @selection
    assert_not_includes tonight, yesterday
  end

  test "armed returns enabled + pending" do
    @selection.save!
    disabled = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Disabled",
      scheduled_date: Date.current + 2,
      status: "pending",
      enabled: false
    )

    armed = NightshiftSelection.armed
    assert_includes armed, @selection
    assert_not_includes armed, disabled
  end
end
