# frozen_string_literal: true

class FactoryCycleTimeoutJob < ApplicationJob
  queue_as :default

  # If the cycle log is gone, nothing to timeout
  discard_on ActiveRecord::RecordNotFound

  def perform(cycle_log_id)
    cycle_log = FactoryCycleLog.find_by(id: cycle_log_id)
    return unless cycle_log
    return unless %w[pending running].include?(cycle_log.status)

    FactoryEngineService.new.record_cycle_result(
      cycle_log,
      status: "timed_out",
      summary: "Cycle timed out after #{FactoryEngineService::TIMEOUT_MINUTES} minutes"
    )
  end
end
