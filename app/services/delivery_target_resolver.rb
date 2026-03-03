# frozen_string_literal: true

# Resolves the canonical delivery target for task outcomes.
# Precedence is deterministic to avoid routing flapping across channels:
# 1) origin_session_key -> OpenClaw session delivery
# 2) origin_chat_id    -> Telegram delivery (thread optional)
# 3) none              -> no external delivery target
class DeliveryTargetResolver
  Resolution = Struct.new(
    :channel,
    :session_key,
    :session_id,
    :chat_id,
    :thread_id,
    :reason,
    :source,
    keyword_init: true
  ) do
    def to_h
      {
        channel: channel,
        session_key: session_key,
        session_id: session_id,
        chat_id: chat_id,
        thread_id: thread_id,
        reason: reason,
        source: source
      }.compact
    end

    def session?
      channel == :session
    end

    def telegram?
      channel == :telegram
    end

    def none?
      channel == :none
    end
  end

  class << self
    def resolve(task)
      return none_resolution("task_missing") unless task

      session_key = task.origin_session_key.to_s.strip
      session_id = task.origin_session_id.to_s.strip
      chat_id = task.origin_chat_id.to_s.strip
      thread_id = normalize_thread_id(task.origin_thread_id)

      if session_key.present?
        return Resolution.new(
          channel: :session,
          session_key: session_key,
          session_id: session_id.presence,
          reason: "origin_session_key_present",
          source: "task.origin"
        )
      end

      if chat_id.present?
        return Resolution.new(
          channel: :telegram,
          chat_id: chat_id,
          thread_id: thread_id,
          session_id: session_id.presence,
          reason: "origin_chat_id_present",
          source: "task.origin"
        )
      end

      none_resolution("missing_origin_delivery_fields")
    rescue StandardError => e
      none_resolution("resolver_error:#{e.class}")
    end

    private

    def normalize_thread_id(value)
      return nil if value.blank?

      str = value.to_s.strip
      return nil unless str.match?(/\A\d+\z/)

      str.to_i
    end

    def none_resolution(reason)
      Resolution.new(channel: :none, reason: reason, source: "task.origin")
    end
  end
end
