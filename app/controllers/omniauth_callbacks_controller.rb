# frozen_string_literal: true

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
    # Sanitize user-controlled param to prevent reflected XSS via flash message.
    # Only allow known OmniAuth failure messages; fall back to generic text.
    known_messages = %w[csrf_detected invalid_credentials no_authorization_code timeout]
    safe_message = if known_messages.include?(params[:message].to_s)
                     params[:message].to_s.humanize
    else
                     "Please try again"
    end
    redirect_to new_session_path, alert: "Authentication failed: #{safe_message}"
  end
end
