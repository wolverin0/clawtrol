class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  redirect_authenticated_users only: %i[new]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  layout "auth", only: %i[new]

  def new
  end

  GENERIC_LOGIN_ERROR = "Invalid email or password."

  def create
    user = User.find_by(email_address: params[:email_address])

    # Use a generic error for all failure paths to prevent user enumeration.
    # An attacker should NOT be able to distinguish "no account", "OAuth-only",
    # or "wrong password" from the error message alone.
    if user.nil?
      redirect_to new_session_path, alert: GENERIC_LOGIN_ERROR
      return
    end

    if user.needs_password? || !user.password_user?
      # OAuth user or legacy user without password — same generic error
      redirect_to new_session_path, alert: GENERIC_LOGIN_ERROR
      return
    end

    if user.authenticate(params[:password])
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Welcome back!"
    else
      redirect_to new_session_path, alert: GENERIC_LOGIN_ERROR
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end
end
