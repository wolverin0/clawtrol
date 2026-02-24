class MissionControlController < ApplicationController
  before_action :set_no_store_cache_headers

  SNAPSHOT_CACHE_KEY = "mission_control/health_snapshot/v1"
  SNAPSHOT_CACHE_TTL = 30.seconds

  def index
    snapshot = Rails.cache.fetch(SNAPSHOT_CACHE_KEY, expires_in: SNAPSHOT_CACHE_TTL) do
      MissionControlHealthSnapshotService.call
    end

    @ruby_version = snapshot[:ruby_version]
    @rails_version = snapshot[:rails_version]
    @environment = snapshot[:environment]
    @database_connected = snapshot[:database_connected]
    @pending_migrations = snapshot[:pending_migrations]
    @uptime = snapshot[:uptime]
    @memory_usage = snapshot[:memory_usage]
  end

  private

  def set_no_store_cache_headers
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end
