# frozen_string_literal: true

require "json"
require_relative "legacy_execution_policy"

module SafeLan
  class LegacyExecutionBlocker
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      return @app.call(env) unless LegacyExecutionPolicy.blocked_request?(request)

      api_request = request.path.start_with?("/api/")
      body = api_request ?
        { error: "Gone", reason: "safe_lan_legacy_execution_disabled" }.to_json :
        "This legacy execution surface is retired in Safe-LAN mode."

      [
        410,
        {
          "Content-Type" => api_request ? "application/json; charset=utf-8" : "text/plain; charset=utf-8",
          "Cache-Control" => "no-store",
          "X-Content-Type-Options" => "nosniff"
        },
        [body]
      ]
    end
  end
end
