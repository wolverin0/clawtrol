# frozen_string_literal: true

require "net/http"
require "uri"
require "cgi"

class DailyExecutiveDigestService
  DEFAULT_MISSION_CONTROL_THREAD_ID = 1

  def initialize(user)
    @user = user
  end

  def call
    return unless telegram_configured?

    send_telegram(format_digest)
  end

  def format_digest
    time_range = Time.current.beginning_of_day..Time.current.end_of_day

    done_tasks = @user.tasks.where(status: "done", updated_at: time_range)
    failed_tasks = @user.tasks.where.not(error_at: nil).where(updated_at: time_range)
    blocked_tasks = @user.tasks.where(blocked: true)
    next_tasks = @user.tasks.where(status: "up_next").order(priority: :desc, position: :asc).limit(3)

    digest = "📊 <b>Daily Executive Digest</b>\n\n"

    digest += "✅ <b>Done Today (#{done_tasks.count}):</b>\n"
    if done_tasks.any?
      done_tasks.limit(5).each { |t| digest += "• #{escape_html(t.name)}\n" }
      digest += "• <i>...and #{done_tasks.count - 5} more</i>\n" if done_tasks.count > 5
    else
      digest += "• <i>No tasks completed</i>\n"
    end
    digest += "\n"

    if failed_tasks.any?
      digest += "❌ <b>Failed Today (#{failed_tasks.count}):</b>\n"
      failed_tasks.limit(5).each { |t| digest += "• #{escape_html(t.name)}\n" }
      digest += "• <i>...and #{failed_tasks.count - 5} more</i>\n" if failed_tasks.count > 5
      digest += "\n"
    end

    if blocked_tasks.any?
      digest += "🚧 <b>Blocked (#{blocked_tasks.count}):</b>\n"
      blocked_tasks.limit(5).each { |t| digest += "• #{escape_html(t.name)}\n" }
      digest += "• <i>...and #{blocked_tasks.count - 5} more</i>\n" if blocked_tasks.count > 5
      digest += "\n"
    end

    digest += "⏭️ <b>Up Next (Top 3):</b>\n"
    if next_tasks.any?
      next_tasks.each { |t| digest += "• #{escape_html(t.name)}\n" }
    else
      digest += "• <i>Inbox zero!</i>\n"
    end

    digest
  end

  private

  def escape_html(value)
    CGI.escapeHTML(value.to_s)
  end

  def telegram_bot_token
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"].presence || ENV["TELEGRAM_BOT_TOKEN"].presence
  end

  def telegram_chat_id
    @user.telegram_chat_id.presence || ENV["CLAWTROL_TELEGRAM_CHAT_ID"].presence || ENV["TELEGRAM_CHAT_ID"].presence
  end

  def telegram_configured?
    telegram_bot_token.present? && telegram_chat_id.present?
  end

  def send_telegram(message)
    uri = URI("https://api.telegram.org/bot#{telegram_bot_token}/sendMessage")

    params = {
      chat_id: telegram_chat_id,
      text: message,
      parse_mode: "HTML"
    }

    # Default to Mission Control thread if available
    params[:message_thread_id] = DEFAULT_MISSION_CONTROL_THREAD_ID

    Net::HTTP.post_form(uri, params)
  rescue StandardError => e
    Rails.logger.warn("[DailyExecutiveDigest] Telegram failed for User #{@user.id}: #{e.message}")
  end
end
