# frozen_string_literal: true

require "test_helper"

class NightshiftTimeoutSweeperJobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @mission = NightshiftMission.create!(
      name: "Sweeper Test Mission",
      user: @user,
      frequency: "always",
      category: "general",
      estimated_minutes: 30,
      model: "gemini"
    )
  end

  def create_selection(status: "pending", launched_at: nil, scheduled_date: Date.current)
    NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Test Selection #{SecureRandom.hex(4)}",
      scheduled_date: scheduled_date,
      status: status,
      launched_at: launched_at
    )
  end

  test "performs without errors when no stale selections exist" do
    assert_nothing_raised do
      NightshiftTimeoutSweeperJob.perform_now
    end
  end

  test "ignores pending selections" do
    sel = create_selection(status: "pending")

    NightshiftTimeoutSweeperJob.perform_now

    sel.reload
    assert_equal "pending", sel.status
  end

  test "ignores completed selections" do
    sel = create_selection(status: "completed", launched_at: 2.hours.ago)

    NightshiftTimeoutSweeperJob.perform_now

    sel.reload
    assert_equal "completed", sel.status
  end

  test "ignores recently launched running selections" do
    sel = create_selection(status: "running", launched_at: 5.minutes.ago)

    NightshiftTimeoutSweeperJob.perform_now

    sel.reload
    assert_equal "running", sel.status
  end

  test "times out stale running selections" do
    sel = create_selection(status: "running", launched_at: 50.minutes.ago)

    NightshiftTimeoutSweeperJob.perform_now

    sel.reload
    assert_equal "failed", sel.status
    assert_includes sel.result, "Timed out"
    assert_not_nil sel.completed_at
  end

  test "only affects today's selections" do
    # Create a stale running selection for yesterday — should NOT be timed out
    # because for_tonight scopes to Date.current
    sel = create_selection(
      status: "running",
      launched_at: 50.minutes.ago,
      scheduled_date: Date.yesterday
    )

    NightshiftTimeoutSweeperJob.perform_now

    sel.reload
    assert_equal "running", sel.status
  end

  test "handles multiple stale selections" do
    sel1 = create_selection(status: "running", launched_at: 1.hour.ago)

    # Need a different mission for unique constraint (mission_id + scheduled_date)
    mission2 = NightshiftMission.create!(
      name: "Second Mission",
      user: @user,
      frequency: "always",
      category: "general",
      estimated_minutes: 15,
      model: "opus"
    )
    sel2 = NightshiftSelection.create!(
      nightshift_mission: mission2,
      title: "Second Stale Selection",
      scheduled_date: Date.current,
      status: "running",
      launched_at: 2.hours.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    assert_equal "failed", sel1.reload.status
    assert_equal "failed", sel2.reload.status
  end
end
