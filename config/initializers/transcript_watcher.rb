# frozen_string_literal: true

# Start the TranscriptWatcher for real-time agent output streaming
#
# Only starts in web server context (Puma) to avoid:
# - Rails console sessions
# - Rake tasks
# - Test runners
# - Background job workers (they don't need it)
#
# The watcher uses the Listen gem to monitor ~/.openclaw/agents/main/sessions/*.jsonl
# and broadcasts changes via ActionCable.

Rails.application.config.after_initialize do
  # Only run in development or production
  next unless Rails.env.development? || Rails.env.production?

  # Guard: only start in web server process, not console/rake/test
  # Puma sets $PROGRAM_NAME or we can check for Rails::Server
  is_web_server = defined?(Puma) ||
                  defined?(Rails::Server) ||
                  $PROGRAM_NAME.include?("puma") ||
                  $PROGRAM_NAME.include?("rails server") ||
                  ENV["RAILS_SERVE_STATIC_FILES"].present?  # Common in production

  # Extra guard: don't start in console or rake
  is_console = defined?(Rails::Console)
  is_rake = $PROGRAM_NAME.include?("rake") || ENV["RAILS_ENV_RUNNING_RAKE"].present?
  is_test = Rails.env.test? || $PROGRAM_NAME.include?("rspec") || $PROGRAM_NAME.include?("test")

  if is_web_server && !is_console && !is_rake && !is_test
    Rails.logger.info "[TranscriptWatcher] Scheduling start for web server process"

    # Start after a short delay to ensure ActionCable is ready
    Thread.new do
      sleep 2  # Wait for ActionCable to initialize

      begin
        TranscriptWatcher.instance.start
      rescue => e
        Rails.logger.error "[TranscriptWatcher] Failed to start in background: #{e.message}"
      end
    end

    # Register shutdown hook
    at_exit do
      Rails.logger.info "[TranscriptWatcher] Shutting down..."
      TranscriptWatcher.instance.stop
    rescue => e
      # Ignore errors during shutdown
    end
  else
    context = []
    context << "console" if is_console
    context << "rake" if is_rake
    context << "test" if is_test
    context << "not web server" unless is_web_server
    Rails.logger.debug "[TranscriptWatcher] Skipping start (#{context.join(', ')})"
  end
end
