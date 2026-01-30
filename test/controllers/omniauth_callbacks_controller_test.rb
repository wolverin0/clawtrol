require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  test "github callback without auth data redirects with error" do
    get omniauth_callback_path(provider: "github")

    assert_redirected_to new_session_path
    assert_equal "Authentication failed. Please try again.", flash[:alert]
  end

  test "failure redirects with error message" do
    get auth_failure_path, params: { message: "access_denied" }

    assert_redirected_to new_session_path
    assert_equal "Authentication failed: Access denied", flash[:alert]
  end
end
