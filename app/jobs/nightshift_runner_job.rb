# frozen_string_literal: true

class NightshiftRunnerJob < ApplicationJob
  queue_as :default

  # Fire-and-forget: wake OpenClaw for each armed selection, then return.
  # Completion is handled by report_execution callback from the cron.
  # A separate NightshiftTimeoutSweeperJob handles stale "running" selections.
  def perform
    NightshiftSelection.for_tonight.armed.includes(:nightshift_mission).order(:id).find_each do |selection|
      launch_selection(selection)
    end
  end

  private

  def launch_selection(selection)
    selection.update!(status: "running", launched_at: Time.current)
    wake_openclaw!(selection)
    Rails.logger.info("[NightshiftRunner] Launched mission '#{selection.title}' (selection ##{selection.id})")
  rescue StandardError => e
    Rails.logger.error("[NightshiftRunner] Failed to launch '#{selection.title}': #{e.message}")
    NightshiftEngineService.new.complete_selection(
      selection,
      status: "failed",
      result: "Launch error: #{e.message}"
    )
  end

  def wake_openclaw!(selection)
    mission = selection.nightshift_mission
    user = (selection.nightshift_mission.respond_to?(:user) && selection.nightshift_mission.user) || User.find_by(admin: true)
    unless user
      Rails.logger.warn("[NightshiftRunnerJob] No user found for selection ##{selection.id}, skipping wake")
      return
    end

    wake_text = <<~TEXT
      Nightshift mission "#{mission.name}" (selection ##{selection.id})
      Description: #{mission.description.presence || "(none)"}
      Model preference: #{mission.model}

      When done, report results to:
      curl -X POST http://192.168.100.186:4001/api/v1/nightshift/report_execution \\
        -H "X-Hook-Token: $CLAWTROL_HOOKS_TOKEN" \\
        -H "Content-Type: application/json" \\
        -d '{"mission_name": "#{mission.name}", "status": "completed", "result": "summary of what was done"}'
    TEXT

    uri = URI.parse("#{user.openclaw_gateway_url}/hooks/wake")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5

    token = if user.respond_to?(:openclaw_hooks_token) && user.openclaw_hooks_token.present?
      user.openclaw_hooks_token
    else
      user.openclaw_gateway_token
    end

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{token}"
    })
    request.body = { text: wake_text, mode: "now" }.to_json

    response = http.request(request)
    return if response.is_a?(Net::HTTPSuccess)

    raise "Wake failed (#{response.code}): #{response.body}"
  end
end
