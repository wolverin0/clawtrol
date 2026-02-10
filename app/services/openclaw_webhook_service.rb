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

    send_webhook(task, "Execute Now: #{task.name}")
  end

  def notify_auto_claimed(task)
    return unless configured?

    send_webhook(task, "Auto-claimed task ##{task.id}: #{task.name}")
  end

  # Auto-pull signal from ClawTrol (server-side).
  #
  # This is WAKE only. The OpenClaw orchestrator should fetch the task from
  # ClawTrol's API and decide how/when to spawn work (model/persona).
  def notify_auto_pull_ready(task)
    return unless configured?

    persona =
      if task.agent_persona
        "#{task.agent_persona.emoji || '🤖'} #{task.agent_persona.name}"
      else
        "none"
      end

    model = task.model.presence || Task::DEFAULT_MODEL
    send_webhook(task, "Auto-pull ready: ##{task.id} #{task.name} (model: #{model}, persona: #{persona})")
  end

  private

  def hook_token
    if @user.respond_to?(:openclaw_hooks_token)
      @user.openclaw_hooks_token.to_s.strip
    else
      ""
    end
  end

  def auth_token
    # Back-compat: older installs stored the hooks token in openclaw_gateway_token.
    hook_token.presence || @user.openclaw_gateway_token.to_s.strip
  end

  def send_webhook(task, message)
    uri = URI.parse("#{@user.openclaw_gateway_url}/hooks/wake")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{auth_token}"
    })
    request.body = {
      text: message,
      mode: "now"
    }.to_json

    response = http.request(request)

    # Wake failures should never be fatal to task claiming. Log and move on.
    code = response.code.to_i
    if code >= 200 && code < 300
      Rails.logger.info("[OpenClawWebhook] wake ok task_id=#{task.id} code=#{response.code}")
    else
      Rails.logger.warn("[OpenClawWebhook] wake non-2xx task_id=#{task.id} code=#{response.code}")
    end

    response
  rescue StandardError => e
    Rails.logger.error("[OpenClawWebhook] wake failed task_id=#{task.id} err=#{e.class}: #{e.message}")
    nil
  end

  def configured?
    url = @user.openclaw_gateway_url.to_s.strip
    token = auth_token
    return false if url.blank? || token.blank?
    return false if url.match?(/example/i)
    true
  end
end
