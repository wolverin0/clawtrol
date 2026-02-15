# frozen_string_literal: true

require "test_helper"

class NightshiftTimeoutSweeperJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @mission = NightshiftMission.create!(
      name: "Sweeper Test Mission",
      user: @user
    )
  end

  test "times out stale running selections" do
    stale = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Stale selection",
      scheduled_date: Date.current,
      status: "running",
      launched_at: 50.minutes.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    stale.reload
    assert_equal "failed", stale.status
    assert_match(/timed out/i, stale.result.to_s)
    assert_not_nil stale.completed_at
  end

  test "does not time out recent running selections" do
    recent = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Recent selection",
      scheduled_date: Date.current,
      status: "running",
      launched_at: 10.minutes.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    recent.reload
    assert_equal "running", recent.status
  end

  test "ignores completed selections" do
    completed = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Done selection",
      scheduled_date: Date.current,
      status: "completed",
      launched_at: 2.hours.ago,
      completed_at: 1.hour.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    completed.reload
    assert_equal "completed", completed.status
  end

  test "ignores pending selections" do
    pending_sel = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Pending selection",
      scheduled_date: Date.current,
      status: "pending"
    )

    NightshiftTimeoutSweeperJob.perform_now

    pending_sel.reload
    assert_equal "pending", pending_sel.status
  end

  test "ignores selections from other days" do
    yesterday = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Yesterday selection",
      scheduled_date: Date.yesterday,
      status: "running",
      launched_at: 2.hours.ago
    )

    NightshiftTimeoutSweeperJob.perform_now

    yesterday.reload
    assert_equal "running", yesterday.status  # not swept — wrong date
  end

  test "handles no stale selections gracefully" do
    assert_nothing_raised do
      NightshiftTimeoutSweeperJob.perform_now
    end
  end
end
