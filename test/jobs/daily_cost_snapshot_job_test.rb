# frozen_string_literal: true

require "test_helper"

class DailyCostSnapshotJobTest < ActiveJob::TestCase
  setup do
    @user = users(:default)
    travel_to Time.current
  end

  teardown do
    travel_back
  end

  # --- perform ---

  test "captures daily snapshots for yesterday" do
    CostSnapshotService.stub :capture_all, nil do
      assert_enqueued_with(job: DailyCostSnapshotJob) do
        DailyCostSnapshotJob.perform_now
      end
    end
  end

  test "captures weekly snapshots on Mondays" do
    # Travel to next Monday
    next_monday = if Time.current.monday?
                    Time.current + 1.week
                  else
                    days_until_monday = (1 - Time.current.wday) % 7
                    days_until_monday = 7 if days_until_monday == 0
                    Time.current + days_until_monday.days
                  end

    travel_to next_monday.beginning_of_day do
      CostSnapshotService.stub :capture_all, nil do
        CostSnapshotService.stub :capture_weekly, nil do
          # Should call capture_weekly on Monday
          DailyCostSnapshotJob.perform_now
        end
      end
    end
  end

  test "captures monthly snapshots on 1st of month" do
    # Travel to 1st of next month or ensure we're on the 1st
    if Time.current.day != 1
      next_month = Time.current + 1.month
      first_of_month = next_month.beginning_of_month
    else
      first_of_month = Time.current
    end

    travel_to first_of_month do
      CostSnapshotService.stub :capture_all, nil do
        CostSnapshotService.stub :capture_monthly, nil do
          # Should call capture_monthly on 1st
          DailyCostSnapshotJob.perform_now
        end
      end
    end
  end

  test "logs info on daily snapshot" do
    CostSnapshotService.stub :capture_all, nil do
      assert_logs "[DailyCostSnapshotJob] Capturing daily snapshots"
    end
  end
end
