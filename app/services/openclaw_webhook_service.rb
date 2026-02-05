# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class OpenclawWebhookService
  def initialize(user)
    @user = user
  end

  def notify_task_assigned(task)
    return unless configured?

    send_webhook(task, "🚀 Execute Now: #{task.name}")
  end

  def notify_auto_claimed(task)
    return unless configured?

    send_webhook(task, "🤖 Auto-claimed task ##{task.id}: #{task.name}")
  end

  private

  def send_webhook(task, message)
    uri = URI.parse("#{@user.openclaw_gateway_url}/api/cron/wake")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@user.openclaw_gateway_token}"
    })
    request.body = {
      text: message,
      mode: "now"
    }.to_json

    response = http.request(request)
    Rails.logger.info "OpenClaw webhook sent for task #{task.id}: #{response.code}"
    response
  rescue StandardError => e
    Rails.logger.error "OpenClaw webhook failed for task #{task.id}: #{e.message}"
    nil
  end

  def configured?
    @user.openclaw_gateway_url.present? && @user.openclaw_gateway_token.present?
  end
end
