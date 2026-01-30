# Preview all emails at http://localhost:3000/rails/mailers/verification_code_mailer
class VerificationCodeMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/verification_code_mailer/send_code
  def send_code
    VerificationCodeMailer.send_code
  end
end
