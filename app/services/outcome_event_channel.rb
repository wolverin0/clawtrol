# frozen_string_literal: true

require "json"

# Durable outcome event channel with Redis-backed queue + notify signal.
# Falls back to in-memory queue when Redis is unavailable.
class OutcomeEventChannel
  LIST_KEY = "clawtrol:outcome_events"
  NOTIFY_CHANNEL = "clawtrol:outcome_events:notify"

  @memory_queue = Queue.new
  @redis_checked = false
  @redis_available = false

  class << self
    def publish!(event)
      payload = normalize_event(event)

      if redis_available?
        redis_client.rpush(LIST_KEY, JSON.generate(payload))
        redis_client.publish(NOTIFY_CHANNEL, payload["event_id"].to_s)
      else
        enqueue_memory(payload)
        notify_in_process(payload)
      end

      payload
    rescue StandardError => e
      Rails.logger.warn("[OutcomeEventChannel] Redis publish failed: #{e.class}: #{e.message}")
      enqueue_memory(payload)
      notify_in_process(payload)
      payload
    end

    def pop
      if redis_available?
        raw = redis_client.lpop(LIST_KEY)
        raw.present? ? JSON.parse(raw) : nil
      else
        @memory_queue.pop(true)
      end
    rescue ThreadError
      nil
    rescue StandardError => e
      Rails.logger.warn("[OutcomeEventChannel] pop failed: #{e.class}: #{e.message}")
      nil
    end

    def redis_available?
      return @redis_available if @redis_checked

      @redis_checked = true
      @redis_available = !!redis_client
    end

    private

    def normalize_event(event)
      payload = event.to_h.deep_stringify_keys
      payload["event_id"] ||= SecureRandom.uuid
      payload["created_at"] ||= Time.current.iso8601
      payload["delivery_attempts"] ||= 0
      payload["last_error"] ||= nil
      payload["delivered_at"] ||= nil
      payload
    end

    def enqueue_memory(payload)
      @memory_queue << payload
    end

    def notify_in_process(payload)
      ActiveSupport::Notifications.instrument("outcome_event.notify", payload: payload)
    rescue StandardError
      # Best-effort only; no-op on failures.
    end

    def redis_client
      return @redis_client if defined?(@redis_client)

      url = ENV["REDIS_URL"].to_s.strip
      return @redis_client = nil if url.blank?

      @redis_client = build_redis_client(url)
    end

    def build_redis_client(url)
      if defined?(Redis)
        Redis.new(url: url)
      else
        begin
          require "redis"
          return Redis.new(url: url)
        rescue LoadError
          # Try redis-client if available
        end

        if defined?(RedisClient)
          RedisClientAdapter.new(RedisClient.new(url: url))
        else
          begin
            require "redis-client"
            RedisClientAdapter.new(RedisClient.new(url: url))
          rescue LoadError
            nil
          end
        end
      end
    rescue StandardError => e
      Rails.logger.warn("[OutcomeEventChannel] Redis client unavailable: #{e.class}: #{e.message}")
      nil
    end
  end

  # Minimal adapter for redis-client gem.
  class RedisClientAdapter
    def initialize(client)
      @client = client
    end

    def rpush(key, value)
      @client.call("RPUSH", key, value)
    end

    def lpop(key)
      @client.call("LPOP", key)
    end

    def publish(channel, message)
      @client.call("PUBLISH", channel, message)
    end
  end
end
