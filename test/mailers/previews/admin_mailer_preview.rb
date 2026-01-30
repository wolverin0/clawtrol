# Preview all emails at http://localhost:3000/rails/mailers/admin_mailer
class AdminMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/admin_mailer/new_user_signup
  def new_user_signup
    AdminMailer.new_user_signup(User.first || User.new(email_address: "example@example.com", created_at: Time.current))
  end
end
