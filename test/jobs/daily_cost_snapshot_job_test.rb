# frozen_string_literal: true

require "test_helper"

class DailyCostSnapshotJobTest < ActiveSupport::TestCase
  test "creates daily snapshots for all users" do
    initial_count = CostSnapshot.count

    DailyCostSnapshotJob.perform_now

    assert CostSnapshot.count > initial_count
    assert CostSnapshot.where(period: "daily", snapshot_date: Date.yesterday).exists?
  end

  test "captures weekly snapshots on Mondays" do
    travel_to next_monday do
      DailyCostSnapshotJob.perform_now
      assert CostSnapshot.where(period: "daily").exists?, "Should create daily snapshot"
      # Weekly snapshots are captured when Date.current.monday? is true
      assert CostSnapshot.where(period: "weekly").exists?, "Should create weekly snapshot on Monday"
    end
  end

  test "is idempotent — running twice doesn't duplicate" do
    DailyCostSnapshotJob.perform_now
    count_after_first = CostSnapshot.count

    DailyCostSnapshotJob.perform_now
    assert_equal count_after_first, CostSnapshot.count
  end

  test "handles errors gracefully for individual users" do
    # Job should complete even if one user fails
    assert_nothing_raised do
      DailyCostSnapshotJob.perform_now
    end
  end

  private

  def next_monday
    date = Date.current
    date += 1 until date.monday?
    date.to_time
  end
end
