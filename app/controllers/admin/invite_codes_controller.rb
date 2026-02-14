module Admin
  class InviteCodesController < ApplicationController
    layout "admin"
    require_admin

    def index
      @invite_codes = InviteCode.order(created_at: :desc)
    end

    def create
      count = (params[:count] || 1).to_i.clamp(1, 10)
      count.times do
        InviteCode.create!(created_by: current_user)
      end
      redirect_to admin_invite_codes_path, notice: "#{count} invite code(s) generated."
    end

    def destroy
      code = InviteCode.find(params[:id])
      code.destroy
      redirect_to admin_invite_codes_path, notice: "Invite code deleted."
    end
  end
end
