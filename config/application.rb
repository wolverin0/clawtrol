require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ClawDeck
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Token used by the unauthenticated /api/v1/hooks/* endpoints.
    # Must be configured via environment (systemd unit, .env, etc.).
    config.hooks_token = ENV.fetch("HOOKS_TOKEN", "")

    # Auto-runner / auto-pull settings
    # Nightly window is a simple guardrail for tasks marked nightly=true.
    # Defaults: 23:00-08:00 in America/Buenos_Aires.
    config.x.auto_runner.nightly_start_hour = ENV.fetch("AUTO_RUNNER_NIGHT_START_HOUR", "23").to_i
    config.x.auto_runner.nightly_end_hour = ENV.fetch("AUTO_RUNNER_NIGHT_END_HOUR", "8").to_i
  end
end
