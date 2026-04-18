# frozen_string_literal: true

# Sentry is enabled only when SENTRY_DSN is configured. Without a DSN, the
# gem is a no-op so the app stays free of error-tracker noise in dev boxes
# and ephemeral test runs.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    config.environment = Rails.env
    config.release = ENV.fetch("SENTRY_RELEASE") { ENV.fetch("GIT_SHA", "unknown") }
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.05").to_f
    config.send_default_pii = false

    # Filter known-benign noise
    config.excluded_exceptions += %w[
      ActionController::RoutingError
      ActiveRecord::RecordNotFound
      ActionController::InvalidAuthenticityToken
    ]

    # Scrub request params that may contain tokens
    config.before_send = lambda do |event, _hint|
      scrubbed = %w[password password_confirmation token api_token bearer
                    authorization secret hooks_token openclaw_gateway_token
                    openclaw_hooks_token ai_api_key telegram_bot_token]
      if event.request&.data.is_a?(Hash)
        scrubbed.each { |k| event.request.data[k] &&= "[FILTERED]" if event.request.data.key?(k) }
      end
      event
    end
  end
end
