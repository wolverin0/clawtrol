class AgentWebhookJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task&.user&.agent_webhook_url.present?

    payload = {
      event: "task.assigned",
      task: {
        id: task.id,
        name: task.name,
        description: task.description,
        status: task.status,
        board_id: task.board_id,
        board_name: task.board.name,
        tags: task.tags,
        url: "https://clawdeck.io/boards/#{task.board_id}"
      },
      timestamp: Time.current.iso8601
    }

    uri = URI.parse(task.user.agent_webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = http.request(request)
    Rails.logger.info "[AgentWebhook] POST to #{uri.host} - #{response.code}"
  rescue => e
    Rails.logger.error "[AgentWebhook] Failed: #{e.message}"
    # Don't retry - webhook failures shouldn't block the app
  end
end
