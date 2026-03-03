# frozen_string_literal: true

class ZeroclawAuditorSweepJob < ApplicationJob
  queue_as :default

  def perform(trigger: "cron_sweep", limit: nil, force: false)
    return unless Zeroclaw::AuditorConfig.enabled?

    result = Zeroclaw::AuditorSweepService.new(
      trigger: trigger,
      limit: limit,
      force: force
    ).call

    Rails.logger.info("[ZeroclawAuditorSweepJob] #{result}")
    result
  rescue StandardError => e
    Rails.logger.error("[ZeroclawAuditorSweepJob] failed: #{e.class}: #{e.message}")
    raise
  end
end
