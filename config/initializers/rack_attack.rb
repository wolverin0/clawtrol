# frozen_string_literal: true

# Rack::Attack Rate Limiting Configuration
#
# Provides API rate limiting with different limits for:
# - Authenticated users: 200 req/min
# - API tokens: 100 req/min
# - Anonymous: 20 req/min
# - Internal (gateway) calls: unlimited (whitelisted)

class Rack::Attack
  # Whitelist internal gateway requests
  safelist("internal") do |req|
    req.env["HTTP_X_INTERNAL_REQUEST"] == "true" ||
      req.env["REMOTE_ADDR"].nil? ||
      req.env["REMOTE_ADDR"].start_with?("127.0.0.1") ||
      req.env["REMOTE_ADDR"].start_with?("192.168.100.")
  end

  # Rate limit by user token for authenticated requests
  throttle("api_by_token", limit: 100, period: 60.seconds) do |req|
    if req.env["warden"]&.user(:user)
      "user:#{req.env['warden'].user(:user).id}"
    elsif req.env["HTTP_AUTHORIZATION"]&.start_with?("Bearer ")
      # Extract token identifier (not the full token)
      token = req.env["HTTP_AUTHORIZATION"][/Bearer (.+)/, 1]
      "token:#{Digest::SHA256.hexdigest(token.to_s)[0..16]}" if token
    end
  end

  # Stricter limit for anonymous requests
  throttle("anonymous", limit: 20, period: 60.seconds) do |req|
    # Only throttle if no user and no valid token
    unless req.env["warden"]&.user(:user) || req.env["HTTP_AUTHORIZATION"]
      req.ip
    end
  end

  # Extra strict limit for write operations (POST/PUT/DELETE/PATCH)
  throttle("write_operations", limit: 30, period: 60.seconds) do |req|
    if %w[POST PUT DELETE PATCH].include?(req.request_method) && req.path.start_with?("/api/")
      if req.env["warden"]&.user(:user)
        "write:#{req.env['warden'].user(:user).id}"
      else
        "write:anon:#{req.ip}"
      end
    end
  end

  # Custom throttle for task creation (prevent spam)
  throttle("task_creation", limit: 10, period: 60.seconds) do |req|
    if req.post? && req.path =~ %r{/api/v1/tasks$}
      if req.env["warden"]&.user(:user)
        "create_task:#{req.env['warden'].user(:user).id}"
      end
    end
  end

  # Track rate-limited requests for monitoring
  self.throttled_response_retry_after_header = true

  # Custom response when rate limited
  throttled_response do |env|
    retry_after = (env["rack.attack.match_data"] || {})["period"] || 60

    [
      429,
      {
        "Content-Type" => "application/json",
        "X-RateLimit-Retry-After" => retry_after.to_s
      },
      [
        {
          error: "Rate limit exceeded",
          message: "Too many requests. Please wait before retrying.",
          retry_after: retry_after
        }.to_json
      ]
    ]
  end
end
