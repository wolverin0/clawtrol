module Admin
  class DashboardController < ApplicationController
    layout "admin"
    require_admin

    def index
      @total_users = User.count
      @total_projects = Project.count
      @total_tasks = Task.count
      @recent_signups = User.where("created_at >= ?", 7.days.ago).count
    end
  end
end
