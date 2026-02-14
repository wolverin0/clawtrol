# frozen_string_literal: true

class FactoryRunnerJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(loop_id) { "factory_loop_#{loop_id}" }, to: 1

  def perform(loop_id)
    loop = FactoryLoop.find_by(id: loop_id)
    return unless loop&.playing?

    # Create cycle log with advisory lock to prevent duplicate cycle numbers
    # even if limits_concurrency fails or is bypassed.
    cycle_log = nil
    begin
      FactoryLoop.transaction do
        loop.lock!
        next_cycle = (loop.factory_cycle_logs.maximum(:cycle_number) || 0) + 1
        cycle_log = loop.factory_cycle_logs.create!(
          cycle_number: next_cycle,
          status: "pending",
          started_at: Time.current,
          state_before: loop.state
        )
      end
    rescue ActiveRecord::RecordNotUnique
      # Race condition: another job already created this cycle number.
      # Safe to skip — the other job will handle this cycle.
      Rails.logger.warn("[FactoryRunnerJob] Duplicate cycle detected for loop #{loop_id}, skipping")
      return
    end

    # Wake OpenClaw
    wake_succeeded = false
    begin
      user = (loop.respond_to?(:user) && loop.user) || User.find_by(admin: true)
      unless user
        Rails.logger.warn("[FactoryRunnerJob] No user found for loop ##{loop.id}, skipping wake")
        cycle_log.update!(status: "failed", error_message: "No user found for loop")
        return
      end
      next_cycle = cycle_log.cycle_number
      wake_text = "Factory cycle ##{cycle_log.id} for loop \"#{loop.name}\" (cycle #{next_cycle}).\n" \
                  "Model: #{loop.model}\n" \
                  "System prompt: #{loop.system_prompt}\n" \
                  "Report results to: POST /api/v1/factory/cycles/#{cycle_log.id}/complete"

      # Use the same wake mechanism as auto-runner
      uri = URI.parse("#{user.openclaw_gateway_url}/hooks/wake")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      token = user.respond_to?(:openclaw_hooks_token) && user.openclaw_hooks_token.present? ? user.openclaw_hooks_token : user.openclaw_gateway_token
      request = Net::HTTP::Post.new(uri.path, {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{token}"
      })
      request.body = { text: wake_text, mode: "now" }.to_json
      http.request(request)

      cycle_log.update!(status: "running")
      wake_succeeded = true
    rescue StandardError => e
      cycle_log.update!(status: "failed", summary: "Wake failed: #{e.message}", finished_at: Time.current)
      loop.increment!(:consecutive_failures)
      loop.increment!(:total_errors)
    end

    # Enqueue timeout watchdog only if wake succeeded (failed cycles are already terminal)
    if wake_succeeded
      FactoryCycleTimeoutJob.set(wait: FactoryEngineService::TIMEOUT_MINUTES.minutes).perform_later(cycle_log.id)
    end

    # Guard: reload to check current status before re-enqueueing
    return unless loop.reload.playing?

    # Re-enqueue self for next cycle
    self.class.set(wait: (loop.interval_ms / 1000.0).seconds).perform_later(loop_id)
  end
end
