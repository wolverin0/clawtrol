require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials logs in user" do
    post session_path, params: { email_address: @user.email_address, password: "password123" }

    assert_redirected_to projects_path
    assert cookies[:session_id]
  end

  test "create with invalid password shows error" do
    post session_path, params: { email_address: @user.email_address, password: "wrongpassword" }

    assert_redirected_to new_session_path
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "create with non-existent email shows error" do
    post session_path, params: { email_address: "nonexistent@example.com", password: "password123" }

    assert_redirected_to new_session_path
    assert_equal "No account found with that email. Please sign up first.", flash[:alert]
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
