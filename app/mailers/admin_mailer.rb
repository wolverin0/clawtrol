class AdminMailer < ApplicationMailer
  def new_user_signup(user)
    @user = user
    @signup_time = user.created_at

    mail(
      to: Rails.application.config.admin_email,
      subject: "New clawdeck.so signup: #{user.email_address}",
      content_type: "text/plain"
    )
  end
end
