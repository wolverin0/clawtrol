# frozen_string_literal: true

# Extracts origin routing attributes for tasks from params/headers.
# Supports Telegram chat/thread and OpenClaw session routing.
class OriginRoutingService
  CHAT_HEADER_KEYS = %w[X-Origin-Chat-Id X-Chat-Id].freeze
  THREAD_HEADER_KEYS = %w[X-Origin-Thread-Id X-Thread-Id].freeze
  SESSION_KEY_HEADER_KEYS = %w[X-Origin-Session-Key X-Session-Key].freeze
  SESSION_ID_HEADER_KEYS = %w[X-Origin-Session-Id X-Session-Id].freeze

  class << self
    def apply!(task, params:, headers: {})
      attrs = extract(params: params, headers: headers)
      attrs.each do |key, value|
        next if value.blank?
        next unless task.respond_to?(key)
        next if task.public_send(key).present?

        task.public_send("#{key}=", value)
      end
      task
    end

    def extract(params:, headers: {})
      task_params = params.is_a?(ActionController::Parameters) ? params[:task] : nil
      task_params = task_params.to_unsafe_h if task_params.is_a?(ActionController::Parameters)
      base_params = params.is_a?(ActionController::Parameters) ? params.to_unsafe_h : params.to_h

      origin_chat_id = fetch_param(base_params, task_params, :origin_chat_id)
      origin_thread_id = fetch_param(base_params, task_params, :origin_thread_id, :thread_id)
      origin_session_key = fetch_param(base_params, task_params, :origin_session_key, :session_key)
      origin_session_id = fetch_param(base_params, task_params, :origin_session_id, :session_id)

      origin_chat_id ||= fetch_header(headers, CHAT_HEADER_KEYS)
      origin_thread_id ||= fetch_header(headers, THREAD_HEADER_KEYS)
      origin_session_key ||= fetch_header(headers, SESSION_KEY_HEADER_KEYS)
      origin_session_id ||= fetch_header(headers, SESSION_ID_HEADER_KEYS)

      {
        origin_chat_id: origin_chat_id.presence,
        origin_thread_id: normalize_thread_id(origin_thread_id),
        origin_session_key: origin_session_key.presence,
        origin_session_id: origin_session_id.presence
      }
    end

    private

    def fetch_param(base_params, task_params, *keys)
      keys.each do |key|
        value = base_params[key] || base_params[key.to_s]
        return value if value.present?

        next unless task_params

        value = task_params[key] || task_params[key.to_s]
        return value if value.present?
      end
      nil
    end

    def fetch_header(headers, keys)
      keys.each do |key|
        value = headers[key] || headers[key.to_s]
        return value if value.present?
      end
      nil
    end

    def normalize_thread_id(value)
      return nil if value.blank?

      str = value.to_s.strip
      return nil if str.blank?

      return str.to_i if str.match?(/\A\d+\z/)

      nil
    end
  end
end
