require "test_helper"

class VerificationCodeMailerTest < ActionMailer::TestCase
  test "send_code" do
    user = users(:one)
    user.generate_verification_code
    user.save

    mail = VerificationCodeMailer.send_code(user)
    assert_equal "Your ClawDeck verification code", mail.subject
    assert_equal [ user.email_address ], mail.to
    assert_match user.verification_code, mail.body.encoded
  end
end
