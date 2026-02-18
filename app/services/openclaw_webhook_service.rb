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

  def notify_auto_pull_ready(task)
    return unless configured?

    persona =
      if task.agent_persona
        "#{task.agent_persona.emoji || '🤖'} #{task.agent_persona.name}"
      else
        "none"
      end

    model = task.model.presence || Task::DEFAULT_MODEL
    origin = origin_routing_text(task)
    send_webhook(task, "Auto-pull ready: ##{task.id} #{task.name} (model: #{model}, persona: #{persona})#{origin}")
  end

  # Pipeline-enriched wake: includes routing/context details only.
  # OpenClaw stays responsible for claim/spawn/execution.
  def notify_auto_pull_ready_with_pipeline(task)
    return unless configured?
    return notify_auto_pull_ready(task) unless task.pipeline_ready?

    persona =
      if task.agent_persona
        "#{task.agent_persona.emoji || '🤖'} #{task.agent_persona.name}"
      else
        "none"
      end

    model = task.routed_model.presence || task.model.presence || Task::DEFAULT_MODEL
    prompt_len = task.compiled_prompt.to_s.length

    send_webhook(
      task,
      "Auto-pull ready: ##{task.id} #{task.name} (model: #{model}, persona: #{persona}, pipeline: #{task.pipeline_stage}, prompt_chars: #{prompt_len})"
    )
  end

  private

  def origin_routing_text(task)
    return "" if task.origin_chat_id.blank?

    text = "\nReport results to Telegram chat: #{task.origin_chat_id}"
    text += " thread: #{task.origin_thread_id}" if task.origin_thread_id.present?
    text
  end

  def hook_token
    if @user.respond_to?(:openclaw_hooks_token)
      @user.openclaw_hooks_token.to_s.strip
    else
      ""
    end
  end

  def auth_token
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

    max_attempts = 3
    retryable_errors = [Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::EHOSTUNREACH]
    attempts = 0

    loop do
      attempts += 1

      begin
        response = http.request(request)
      rescue *retryable_errors => e
        if attempts < max_attempts
          Rails.logger.warn("[OpenClawWebhook] wake retry #{attempts}/#{max_attempts} task_id=#{task.id} err=#{e.class}: #{e.message}")
          sleep(2**(attempts - 1))
          next
        end

        raise
      end

      code = response.code.to_i
      if code >= 500 && attempts < max_attempts
        Rails.logger.warn("[OpenClawWebhook] wake retry #{attempts}/#{max_attempts} task_id=#{task.id} code=#{response.code}")
        sleep(2**(attempts - 1))
        next
      end

      if code >= 200 && code < 300
        Rails.logger.info("[OpenClawWebhook] wake ok task_id=#{task.id} code=#{response.code}")
      else
        Rails.logger.warn("[OpenClawWebhook] wake non-2xx task_id=#{task.id} code=#{response.code}")
        Rails.logger.error("[OpenClawWebhook] wake failed task_id=#{task.id} code=#{response.code}") if code >= 500
      end

      return response
    end
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
