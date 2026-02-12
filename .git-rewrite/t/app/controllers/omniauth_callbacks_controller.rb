class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access only: %i[github failure]

  def github
    auth = request.env["omniauth.auth"]

    if auth.nil?
      redirect_to new_session_path, alert: "Authentication failed. Please try again."
      return
    end

    user = User.find_or_create_from_github(auth)

    if user.persisted?
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Successfully signed in with GitHub!"
    else
      redirect_to new_session_path, alert: "Could not create account. #{user.errors.full_messages.join(', ')}"
    end
  end

  def failure
    redirect_to new_session_path, alert: "Authentication failed: #{params[:message].to_s.humanize}"
  end
end
