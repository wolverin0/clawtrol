class HealthController < ApplicationController
  allow_unauthenticated_access

  def show
    render json: { status: 'ok', time: Time.current }
  end
end
