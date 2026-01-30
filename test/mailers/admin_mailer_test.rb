require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "new_user_signup" do
    user = users(:one)

    mail = AdminMailer.new_user_signup(user)
    assert_equal "New clawdeck.so signup: #{user.email_address}", mail.subject
    assert_equal [ Rails.application.config.admin_email ], mail.to
    assert_equal [ "noreply@clawdeck.so" ], mail.from
    assert_match user.email_address, mail.body.encoded
  end
end
