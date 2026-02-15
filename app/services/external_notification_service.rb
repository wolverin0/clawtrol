require "net/http"
require "uri"

class ExternalNotificationService
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

  def telegram_configured?
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"].present? && @task.origin_chat_id.present?
  end

  def webhook_configured?
    @user&.webhook_notification_url.present?
  end

  def send_telegram
    bot_token = ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"]
    uri = URI("https://api.telegram.org/bot#{bot_token}/sendMessage")

    params = {
      chat_id: @task.origin_chat_id,
      text: format_message,
      parse_mode: "HTML"
    }
    params[:message_thread_id] = @task.origin_thread_id if @task.origin_thread_id.present?

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
