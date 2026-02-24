class MissionControlController < ApplicationController
  before_action :set_no_store_cache_headers

  def index
    snapshot = MissionControlHealthSnapshotService.call

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
    response.headers["Cache-Control"] = "no-store"
  end
end
