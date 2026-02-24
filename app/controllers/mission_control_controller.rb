class MissionControlController < ApplicationController
  def index
    @ruby_version = RUBY_VERSION
    @rails_version = Rails.version
    @environment = Rails.env
    @database_connected = database_connected?
    @pending_migrations = pending_migrations_status

    @uptime = uptime_string
    @memory_usage = memory_usage_mb
  end

  private

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  def pending_migrations_status
    return nil unless @database_connected

    ActiveRecord::Base.connection.migration_context.needs_migration?
  rescue StandardError
    nil
  end

  def uptime_string
    # Simple uptime if boot time was recorded, else system uptime
    `uptime -p`.strip
  rescue
    "Unknown"
  end

  def memory_usage_mb
    "#{(`ps -o rss= -p #{Process.pid}`.to_i / 1024.0).round(2)} MB"
  rescue
    "Unknown"
  end
end