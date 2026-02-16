# frozen_string_literal: true

require "net/http"
require "uri"

class CatastrophicGuardrailsService
  class CatastrophicDataLossError < StandardError; end

  DEFAULT_DROP_PERCENT = 50

  def initialize(mode: ENV.fetch("CLAWDECK_GUARDRAILS_MODE", "alert_only"), source: "unknown")
    @mode = mode.to_s
    @source = source.to_s
  end

  def check!
    # If the DB isn't reachable (migrations, startup), don't take the app down.
    # Just log and exit; the next periodic check will catch it.
    current = current_counts
    previous = Rails.cache.read(cache_key)

    events = []

    if current[:users] == 0
      events << {
        kind: "users_empty",
        message: "User.count==0 (DB may be empty or dropped)",
        current: current,
        previous: previous
      }
    end

    if previous.present?
      drop_percent = ENV.fetch("CLAWDECK_GUARDRAILS_DROP_PERCENT", DEFAULT_DROP_PERCENT).to_i
      events.concat(drop_events_for(:tasks, previous, current, drop_percent))
      events.concat(drop_events_for(:boards, previous, current, drop_percent))
    end

    Rails.cache.write(cache_key, current, expires_in: 30.days)

    events.each { |e| handle_event!(e) }

    events
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad => e
    Rails.logger.warn("[Guardrails] skipped (db unavailable) source=#{@source} err=#{e.class}: #{e.message}")
    []
  end

  private

  def current_counts
    {
      users: User.count,
      boards: Board.count,
      tasks: Task.count
    }
  end

  def drop_events_for(key, previous, current, drop_percent)
    prev = previous[key].to_i
    curr = current[key].to_i
    return [] if prev <= 0
    return [] unless curr < prev

    drop = prev - curr
    pct = (drop.to_f / prev.to_f) * 100.0
    return [] if pct < drop_percent

    [{
      kind: "#{key}_dropped",
      message: "#{key} dropped abruptly (#{prev} → #{curr}, -#{pct.round(1)}%)",
      current: current,
      previous: previous
    }]
  end

  def handle_event!(event)
    msg = format_alert(event)
    Rails.logger.error("[Guardrails] #{msg}")

    create_notification(msg)
    send_telegram_alert(msg)

    raise CatastrophicDataLossError, msg if fail_fast?
  end

  def format_alert(event)
    "CATASTROPHIC_GUARDRAIL kind=#{event[:kind]} source=#{@source} message=#{event[:message]} current=#{event[:current].inspect} previous=#{event[:previous].inspect}"
  end

  def create_notification(message)
    user = User.where(admin: true).first || User.first
    return unless user

    Notification.create!(
      user: user,
      event_type: "catastrophic_guardrail",
      message: message
    )
  rescue StandardError => e
    Rails.logger.warn("[Guardrails] notification failed: #{e.class}: #{e.message}")
  end

  def send_telegram_alert(message)
    bot_token = ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"].presence
    chat_id = ENV["CLAWTROL_TELEGRAM_ALERT_CHAT_ID"].presence

    return unless bot_token && chat_id

    uri = URI("https://api.telegram.org/bot#{bot_token}/sendMessage")
    Net::HTTP.post_form(uri, { chat_id: chat_id, text: message })
  rescue StandardError => e
    Rails.logger.warn("[Guardrails] telegram failed: #{e.class}: #{e.message}")
  end

  def fail_fast?
    @mode == "fail_fast"
  end

  def cache_key
    "clawdeck:guardrails:last_counts"
  end
end
