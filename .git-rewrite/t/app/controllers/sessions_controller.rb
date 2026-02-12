class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  redirect_authenticated_users only: %i[new]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  layout "auth", only: %i[new]

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address])

    if user.nil?
      redirect_to new_session_path, alert: "No account found with that email. Please sign up first."
      return
    end

    if user.needs_password?
      # OAuth user without password - suggest they use GitHub or reset password
      redirect_to new_session_path, alert: "This account uses GitHub login. Please sign in with GitHub or reset your password."
      return
    end

    if !user.password_user?
      # Existing user from before password auth - needs to set password via reset
      redirect_to new_password_path, alert: "Please set a password using the password reset flow."
      return
    end

    if user.authenticate(params[:password])
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Welcome back!"
    else
      redirect_to new_session_path, alert: "Invalid email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end
end
