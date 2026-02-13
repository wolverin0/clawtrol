require "net/http"
require "uri"

class ExternalNotificationService
  def initialize(user)
    @user = user
  end

  def notify_task_completion(task)
    return unless @user.notifications_enabled?

    message = format_message(task)
    send_telegram(message) if telegram_configured?
    send_webhook(task, message) if webhook_configured?
  end

  private

  def format_message(task)
    output = task.respond_to?(:description) ? task.description.to_s.truncate(500) : ""
    status_emoji = task.status == "in_review" ? "📋" : "✅"

    "#{status_emoji} Task ##{task.id} → #{task.status.humanize}\n\n" \
      "#{task.name}\n\n" \
      "#{output}"
  end

  def telegram_configured?
    @user.telegram_bot_token.present? && @user.telegram_chat_id.present?
  end

  def webhook_configured?
    @user.webhook_notification_url.present?
  end

  def send_telegram(message)
    uri = URI("https://api.telegram.org/bot#{@user.telegram_bot_token}/sendMessage")
    Net::HTTP.post_form(uri, {
      chat_id: @user.telegram_chat_id,
      text: message,
      parse_mode: "HTML"
    })
  rescue StandardError => e
    Rails.logger.warn("[ExternalNotification] Telegram failed: #{e.message}")
  end

  def send_webhook(task, message)
    uri = URI(@user.webhook_notification_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri.request_uri.presence || "/", { "Content-Type" => "application/json" })
    request.body = {
      event: "task_status_change",
      task_id: task.id,
      task_name: task.name,
      status: task.status,
      message: message,
      timestamp: Time.current.iso8601
    }.to_json

    http.request(request)
  rescue StandardError => e
    Rails.logger.warn("[ExternalNotification] Webhook failed: #{e.message}")
  end
end
