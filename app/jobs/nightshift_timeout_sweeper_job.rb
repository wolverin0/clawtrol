# frozen_string_literal: true

class NightshiftTimeoutSweeperJob < ApplicationJob
  queue_as :default

  STALE_THRESHOLD = 45.minutes

  # Runs periodically (e.g. every hour via cron) to fail selections stuck in "running"
  def perform
    stale = NightshiftSelection.for_tonight
      .where(status: "running")
      .where("launched_at < ?", STALE_THRESHOLD.ago)

    stale.find_each do |selection|
      NightshiftEngineService.new.complete_selection(
        selection,
        status: "failed",
        result: "Timed out: no report received within #{STALE_THRESHOLD.in_minutes.to_i} minutes of launch"
      )
      Rails.logger.warn("[NightshiftSweeper] Timed out selection ##{selection.id} '#{selection.title}'")
    end
  end
end
