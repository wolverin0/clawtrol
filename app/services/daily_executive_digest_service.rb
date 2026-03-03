# frozen_string_literal: true

require "net/http"
require "uri"
require "cgi"

class DailyExecutiveDigestService
  DEFAULT_MISSION_CONTROL_THREAD_ID = 1
  MAX_LIST_ITEMS = 5

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

    digest = +"📊 <b>Daily Executive Digest</b>\n\n"
    digest << digest_section("✅", "Done Today", done_tasks, empty_message: "No tasks completed")
    digest << digest_section("❌", "Failed Today", failed_tasks) if failed_tasks.exists?
    digest << digest_section("🚧", "Blocked", blocked_tasks) if blocked_tasks.exists?

    digest << "⏭️ <b>Up Next (Top 3):</b>\n"
    if next_tasks.exists?
      next_tasks.pluck(:name).each { |name| digest << "• #{escape_html(name)}\n" }
    else
      digest << "• <i>Inbox zero!</i>\n"
    end

    digest
  end

  private

  def digest_section(emoji, title, relation, empty_message: nil)
    total = relation.count
    section = +"#{emoji} <b>#{title} (#{total}):</b>\n"

    if total.zero?
      section << "• <i>#{empty_message}</i>\n" if empty_message
      return section << "\n"
    end

    relation.limit(MAX_LIST_ITEMS).pluck(:name).each do |name|
      section << "• #{escape_html(name)}\n"
    end

    remaining = total - MAX_LIST_ITEMS
    section << "• <i>...and #{remaining} more</i>\n" if remaining.positive?
    section << "\n"
  end

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
