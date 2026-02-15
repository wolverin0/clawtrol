# frozen_string_literal: true

require "net/http"
require "uri"

class ExternalNotificationService
  DEFAULT_MISSION_CONTROL_THREAD_ID = 1

  def initialize(task)
    @task = task
    @user = task.user
  end

  def notify_task_completion
    send_telegram if telegram_configured?
    send_webhook if webhook_configured?
  end

  private

  def format_message
    output = @task.description.to_s.truncate(500)
    status_emoji = @task.status == "in_review" ? "📋" : "✅"

    "#{status_emoji} Task ##{@task.id} → #{@task.status.humanize}\n\n" \
      "#{@task.name}\n\n" \
      "#{output}"
  end

  def telegram_bot_token
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"].presence || ENV["TELEGRAM_BOT_TOKEN"].presence
  end

  # Prefer the task's recorded origin; fall back to Mission Control chat.
  def telegram_chat_id
    @task.origin_chat_id.presence || default_telegram_chat_id
  end

  # Prefer origin topic; when using Mission Control fallback, explicitly target topic 1
  # (avoid Telegram "last topic" drift).
  def telegram_thread_id
    return @task.origin_thread_id if @task.origin_chat_id.present? && @task.origin_thread_id.present?

    DEFAULT_MISSION_CONTROL_THREAD_ID if @task.origin_chat_id.blank? && default_telegram_chat_id.present?
  end

  def default_telegram_chat_id
    ENV["CLAWTROL_TELEGRAM_CHAT_ID"].presence || ENV["TELEGRAM_CHAT_ID"].presence
  end

  def telegram_configured?
    telegram_bot_token.present? && telegram_chat_id.present?
  end

  def webhook_configured?
    @user&.webhook_notification_url.present?
  end

  def send_telegram
    uri = URI("https://api.telegram.org/bot#{telegram_bot_token}/sendMessage")

    params = {
      chat_id: telegram_chat_id,
      text: format_message,
      parse_mode: "HTML"
    }

    thread_id = telegram_thread_id
    params[:message_thread_id] = thread_id if thread_id.present?

    Net::HTTP.post_form(uri, params)
  rescue StandardError => e
    Rails.logger.warn("[ExternalNotification] Telegram failed: #{e.message}")
  end

  def send_webhook
    message = format_message
    uri = URI(@user.webhook_notification_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri.request_uri.presence || "/", { "Content-Type" => "application/json" })
    request.body = {
      event: "task_status_change",
      task_id: @task.id,
      task_name: @task.name,
      status: @task.status,
      message: message,
      timestamp: Time.current.iso8601
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
          Rails.logger.warn("[ExternalNotification] Webhook retry #{attempts}/#{max_attempts} task_id=#{@task.id} err=#{e.class}: #{e.message}")
          sleep(2**(attempts - 1))
          next
        end

        raise
      end

      code = response.code.to_i
      if code >= 500 && attempts < max_attempts
        Rails.logger.warn("[ExternalNotification] Webhook retry #{attempts}/#{max_attempts} task_id=#{@task.id} code=#{response.code}")
        sleep(2**(attempts - 1))
        next
      end

      return response
    end
  rescue StandardError => e
    Rails.logger.warn("[ExternalNotification] Webhook failed: #{e.message}")
  end
end
