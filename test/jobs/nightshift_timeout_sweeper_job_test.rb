# frozen_string_literal: true

require "test_helper"

class NightshiftTimeoutSweeperJobTest < ActiveJob::TestCase
  setup do
    @user = users(:default)
    @mission = NightshiftMission.create!(
      name: "Test Mission",
      frequency: "always",
      category: "general",
      user: @user
    )
    travel_to Time.current
  end

  teardown do
    travel_back
  end

  # --- perform ---

  test "fails stale running selections" do
    # Create a selection launched 50 minutes ago (stale)
    stale_selection = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Stale Run",
      scheduled_date: Date.current,
      status: "running",
      launched_at: 50.minutes.ago
    )

    # Create a fresh selection (not stale)
    fresh_selection = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Fresh Run",
      scheduled_date: Date.current + 1.day,
      status: "running",
      launched_at: 5.minutes.ago
    )

    # Run the sweeper
    NightshiftTimeoutSweeperJob.perform_now

    # Stale should be failed
    stale_selection.reload
    assert_equal "failed", stale_selection.status
    assert_match /Timed out/, stale_selection.result

    # Fresh should remain running
    fresh_selection.reload
    assert_equal "running", fresh_selection.status
  end

  test "ignores non-running selections" do
    selection = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Pending",
      scheduled_date: Date.current,
      status: "pending",
      launched_at: 50.minutes.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    selection.reload
    assert_equal "pending", selection.status
  end

  test "ignures selections within threshold" do
    selection = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Recent Run",
      scheduled_date: Date.current,
      status: "running",
      launched_at: 10.minutes.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    selection.reload
    assert_equal "running", selection.status
  end
end
