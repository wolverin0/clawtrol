# frozen_string_literal: true

require "open3"

class MissionControlHealthSnapshotService
  def self.call
    new.call
  end

  def call
    database_connected = database_connected?

    {
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      environment: Rails.env,
      database_connected: database_connected,
      pending_migrations: pending_migrations_status(database_connected),
      uptime: uptime_string,
      memory_usage: memory_usage_mb
    }
  end

  private

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  def pending_migrations_status(database_connected)
    return nil unless database_connected

    ActiveRecord::Base.connection.migration_context.needs_migration?
  rescue StandardError
    nil
  end

  def uptime_string
    output, status = Open3.capture2("uptime", "-p")
    return "Unknown" unless status.success?

    output.strip.presence || "Unknown"
  rescue StandardError
    "Unknown"
  end

  def memory_usage_mb
    output, status = Open3.capture2("ps", "-o", "rss=", "-p", Process.pid.to_s)
    return "Unknown" unless status.success?

    rss_kb = output.to_i
    return "Unknown" if rss_kb <= 0

    "#{(rss_kb / 1024.0).round(2)} MB"
  rescue StandardError
    "Unknown"
  end
end
