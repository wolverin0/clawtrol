# frozen_string_literal: true

# Suppresses repeated heartbeat/watchdog alerts until state changes.
class HeartbeatAlertGuard
  CACHE_PREFIX = "heartbeat_alert_guard".freeze

  class << self
    def allow?(key:, state:, ttl: 12.hours, cache: Rails.cache)
      return true if key.blank?

      cache_key = build_key(key)
      previous = cache.read(cache_key)
      if previous.present? && previous == state
        cache.write(cache_key, state, expires_in: ttl)
        return false
      end

      cache.write(cache_key, state, expires_in: ttl)
      true
    rescue StandardError
      true
    end

    def clear!(key, cache: Rails.cache)
      cache.delete(build_key(key))
    rescue StandardError
      # no-op
    end

    private

    def build_key(key)
      "#{CACHE_PREFIX}:#{key}"
    end
  end
end
