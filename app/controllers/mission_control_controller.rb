class MissionControlController < ApplicationController
  def index
    @ruby_version = RUBY_VERSION
    @rails_version = Rails.version
    @environment = Rails.env
    @database_connected = ActiveRecord::Base.connection.active? rescue false
    @pending_migrations = ActiveRecord::Base.connection.migration_context.needs_migration? rescue false
    
    @uptime = uptime_string
    @memory_usage = memory_usage_mb
  end

  private

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