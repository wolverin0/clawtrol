# frozen_string_literal: true

require "net/http"
require "uri"
require "cgi"

class DailyExecutiveDigestService
  def self.call
    new.call
  end

  def call
    User.find_each do |user|
      next unless telegram_configured?(user)
      send_digest(user)
    end
  end

  private

  def telegram_configured?(user)
    telegram_bot_token.present? && telegram_chat_id(user).present?
  end

  def telegram_bot_token
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"].presence || ENV["TELEGRAM_BOT_TOKEN"].presence
  end

  def telegram_chat_id(user)
    user.telegram_chat_id.presence || ENV["CLAWTROL_TELEGRAM_CHAT_ID"].presence || ENV["TELEGRAM_CHAT_ID"].presence
  end

  def send_digest(user)
    today = Time.current.beginning_of_day..Time.current.end_of_day
    
    done = user.tasks.where(status: "done", updated_at: today)
    failed = user.tasks.where.not(error_message: [nil, ""]).where(updated_at: today)
    blocked = user.tasks.where(blocked: true)
    up_next = user.tasks.where(status: "up_next").order(position: :asc).limit(3)

    message = []
    message << "📊 <b>Daily Executive Digest</b>\n"
    
    if done.any?
      message << "✅ <b>Done Today</b> (#{done.count})"
      done.each { |t| message << "• #{escape_html(t.name)}" }
      message << ""
    end

    if failed.any?
      message << "❌ <b>Failed Today</b> (#{failed.count})"
      failed.each { |t| message << "• #{escape_html(t.name)}" }
      message << ""
    end

    if blocked.any?
      message << "🚧 <b>Currently Blocked</b> (#{blocked.count})"
      blocked.each { |t| message << "• #{escape_html(t.name)}" }
      message << ""
    end

    if up_next.any?
      message << "⏭️ <b>Up Next</b> (Top 3)"
      up_next.each { |t| message << "• #{escape_html(t.name)}" }
      message << ""
    end
    
    message << "<i>No significant activity to report.</i>" if done.empty? && failed.empty? && blocked.empty? && up_next.empty?

    send_telegram_message(user, message.join("\n"))
  end

  def escape_html(value)
    CGI.escapeHTML(value.to_s)
  end

  def send_telegram_message(user, text)
    uri = URI("https://api.telegram.org/bot#{telegram_bot_token}/sendMessage")

    params = {
      chat_id: telegram_chat_id(user),
      text: text,
      parse_mode: "HTML"
    }

    Net::HTTP.post_form(uri, params)
  rescue StandardError => e
    Rails.logger.warn("[DailyExecutiveDigest] Telegram failed for User #{user.id}: #{e.message}")
  end
end
