require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create sends verification code" do
    post session_path, params: { email_address: @user.email_address }

    assert_redirected_to verify_session_path(email: @user.email_address)
    assert_equal "Check your email for a verification code.", flash[:notice]
  end

  test "verify with valid code logs in user" do
    @user.generate_verification_code
    @user.save

    post verify_session_path, params: { email: @user.email_address, code: @user.verification_code }

    assert_redirected_to projects_path
    assert cookies[:session_id]
  end

  test "verify with invalid code shows error" do
    post verify_session_path, params: { email: @user.email_address, code: "wrong" }

    assert_redirected_to verify_session_path(email: @user.email_address)
    assert_equal "Invalid or expired code. Please try again.", flash[:alert]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
