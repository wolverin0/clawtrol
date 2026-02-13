class FactoryRunnerJob < ApplicationJob
  queue_as :default

  def perform(loop_id)
    loop = FactoryLoop.find_by(id: loop_id)
    return unless loop&.playing?

    # Create cycle log
    next_cycle = (loop.factory_cycle_logs.maximum(:cycle_number) || 0) + 1
    cycle_log = loop.factory_cycle_logs.create!(
      cycle_number: next_cycle,
      status: "pending",
      started_at: Time.current,
      state_before: loop.state
    )

    # Wake OpenClaw
    begin
      user = (loop.respond_to?(:user) && loop.user) || User.find_by(admin: true) || User.first
      webhook = OpenclawWebhookService.new(user)
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
    rescue => e
      cycle_log.update!(status: "failed", summary: "Wake failed: #{e.message}", finished_at: Time.current)
      loop.increment!(:consecutive_failures)
      loop.increment!(:total_errors)
    end

    # Enqueue timeout watchdog
    FactoryCycleTimeoutJob.set(wait: FactoryEngineService::TIMEOUT_MINUTES.minutes).perform_later(cycle_log.id)

    # Re-enqueue self for next cycle
    self.class.set(wait: (loop.interval_ms / 1000.0).seconds).perform_later(loop_id)
  end
end
