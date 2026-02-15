# frozen_string_literal: true

require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  test "failure with known message shows specific error" do
    get auth_failure_path, params: { message: "csrf_detected" }

    assert_redirected_to new_session_path
    assert_equal "Authentication failed: Csrf detected", flash[:alert]
  end

  test "failure with unknown message shows generic error" do
    # Unknown messages get "Please try again" to avoid leaking internal details
    get auth_failure_path, params: { message: "access_denied" }

    assert_redirected_to new_session_path
    assert_equal "Authentication failed: Please try again", flash[:alert]
  end
end
