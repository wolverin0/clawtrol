class VerificationCodeMailer < ApplicationMailer
  def send_code(user)
    @user = user
    # Reload user to ensure we have the latest verification code from the database
    # This is important when using deliver_later as the job deserializes the user
    @user.reload if @user.persisted?
    @code = @user.verification_code

    mail to: @user.email_address, subject: "Your ClawDeck verification code", content_type: "text/plain"
  end
end
