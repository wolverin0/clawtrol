class NightshiftRunnerJob < ApplicationJob
  queue_as :default

  POLL_INTERVAL_SECONDS = 10

  def perform
    NightshiftSelection.for_tonight.armed.includes(:nightshift_mission).order(:id).find_each do |selection|
      execute_selection(selection)
    end
  end

  private

  def execute_selection(selection)
    selection.update!(status: "running", launched_at: Time.current)
    wake_openclaw!(selection)

    deadline = NightshiftEngineService::TIMEOUT_MINUTES.minutes.from_now
    while Time.current < deadline
      selection.reload
      return if %w[completed failed].include?(selection.status)

      sleep POLL_INTERVAL_SECONDS
    end

    NightshiftEngineService.new.complete_selection(
      selection,
      status: "failed",
      result: "Timed out after #{NightshiftEngineService::TIMEOUT_MINUTES} minutes"
    )
  rescue => e
    NightshiftEngineService.new.complete_selection(
      selection,
      status: "failed",
      result: "Runner error: #{e.message}"
    )
  end

  def wake_openclaw!(selection)
    mission = selection.nightshift_mission
    user = User.first

    wake_text = <<~TEXT
      Nightshift mission "#{mission.name}" (selection ##{selection.id})
      Description: #{mission.description.presence || "(none)"}
      Model preference: #{mission.model}

      Report results to: PATCH /api/v1/nightshift/selections/#{selection.id} with {status: 'completed'/'failed', result: '...'}
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
