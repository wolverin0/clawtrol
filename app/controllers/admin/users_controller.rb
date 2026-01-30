module Admin
  class UsersController < ApplicationController
    layout "admin"
    require_admin

    def index
      @users = User.includes(:sessions, :tasks)
                   .order(created_at: :desc)
                   .map do |user|
        {
          user: user,
          email: user.email_address,
          created_at: user.created_at,
          last_login: user.sessions.maximum(:updated_at),
          tasks_count: user.tasks.count
        }
      end
    end
  end
end
