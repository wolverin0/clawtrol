# frozen_string_literal: true

module Api
  module RateLimitable
    extend ActiveSupport::Concern

    # Simple sliding-window rate limiter using Rails.cache.
    # Usage in controllers:
    #   include Api::RateLimitable
    #   before_action -> { rate_limit!(limit: 60, window: 60) }
    #   before_action -> { rate_limit!(limit: 10, window: 60) }, only: [:create, :update]
    #
    # Returns 429 Too Many Requests with Retry-After header when exceeded.

    private

    # @param limit [Integer] max requests allowed in the window
    # @param window [Integer] window size in seconds
    # @param key_suffix [String] optional suffix to differentiate rate limits
    def rate_limit!(limit: 60, window: 60, key_suffix: nil)
      identifier = rate_limit_identifier
      return if identifier.blank?

      cache_key = "api_rate_limit:#{identifier}:#{key_suffix || controller_path}:#{window}"

      # Atomic increment — returns new value
      count = Rails.cache.increment(cache_key, 1, expires_in: window.seconds)

      # First request? increment returns nil or 1 depending on store
      if count.nil?
        Rails.cache.write(cache_key, 1, expires_in: window.seconds)
        count = 1
      end

      # Set rate limit headers for all responses
      response.set_header("X-RateLimit-Limit", limit.to_s)
      response.set_header("X-RateLimit-Remaining", [limit - count, 0].max.to_s)
      response.set_header("X-RateLimit-Reset", (Time.current + window.seconds).to_i.to_s)

      return if count <= limit

      response.set_header("Retry-After", window.to_s)

      Rails.logger.warn(
        "[RateLimit] #{identifier} exceeded #{limit}/#{window}s on #{controller_path}##{action_name} (count=#{count})"
      )

      render json: {
        error: "Rate limit exceeded",
        limit: limit,
        window: window,
        retry_after: window
      }, status: :too_many_requests
    end

    # Identify the requester: user ID for authenticated, IP for anonymous
    def rate_limit_identifier
      if defined?(@current_user) && @current_user.present?
        "user:#{@current_user.id}"
      else
        "ip:#{request.remote_ip}"
      end
    end
  end
end
