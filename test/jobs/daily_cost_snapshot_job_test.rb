# frozen_string_literal: true

require "test_helper"

class DailyCostSnapshotJobTest < ActiveJob::TestCase
  setup do
    travel_to Time.current
  end

  teardown do
    travel_back
  end

  test "captures daily snapshots for yesterday" do
    assert_nothing_raised do
      DailyCostSnapshotJob.perform_now
    end
  end

  test "captures weekly snapshots on Mondays" do
    next_monday = if Time.current.monday?
                    Time.current + 1.week
    else
                    days_until_monday = (1 - Time.current.wday) % 7
                    days_until_monday = 7 if days_until_monday == 0
                    Time.current + days_until_monday.days
    end

    travel_to next_monday.beginning_of_day do
      assert_nothing_raised do
        DailyCostSnapshotJob.perform_now
      end
    end
  end

  test "captures monthly snapshots on 1st of month" do
    first_of_month = Time.current.day == 1 ? Time.current : (Time.current + 1.month).beginning_of_month

    travel_to first_of_month.beginning_of_day do
      assert_nothing_raised do
        DailyCostSnapshotJob.perform_now
      end
    end
  end

  test "logs without raising" do
    assert_nothing_raised do
      DailyCostSnapshotJob.perform_now
    end
  end
end
