# frozen_string_literal: true

# Captures daily cost snapshots for all users.
# Runs once per day via SolidQueue recurring schedule.
# Also captures weekly (on Mondays) and monthly (on 1st of month).
class DailyCostSnapshotJob < ApplicationJob
  queue_as :default

  def perform
    date = Date.yesterday

    Rails.logger.info("[DailyCostSnapshotJob] Capturing daily snapshots for #{date}")
    CostSnapshotService.capture_all(date: date)

    # Weekly snapshots on Mondays (covers the previous Mon-Sun)
    if Date.current.monday?
      Rails.logger.info("[DailyCostSnapshotJob] Monday — capturing weekly snapshots")
      User.find_each do |user|
        CostSnapshotService.capture_weekly(user, date: 1.week.ago.to_date)
      rescue StandardError => e
        Rails.logger.error("[DailyCostSnapshotJob] Weekly snapshot failed for user #{user.id}: #{e.message}")
      end
    end

    # Monthly snapshots on 1st of month (covers the previous month)
    if Date.current.day == 1
      Rails.logger.info("[DailyCostSnapshotJob] 1st of month — capturing monthly snapshots")
      User.find_each do |user|
        CostSnapshotService.capture_monthly(user, date: Date.current.prev_month)
      rescue StandardError => e
        Rails.logger.error("[DailyCostSnapshotJob] Monthly snapshot failed for user #{user.id}: #{e.message}")
      end
    end

    Rails.logger.info("[DailyCostSnapshotJob] Done")
  end
end
