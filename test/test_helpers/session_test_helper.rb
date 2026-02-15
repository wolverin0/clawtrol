# frozen_string_literal: true

# Shared authentication helpers for all test types.
#
# Integration tests (ActionDispatch::IntegrationTest) use sign_in_as
# which performs a real HTTP POST to the session endpoint.
#
# Unit tests can override with direct cookie manipulation if needed.
module SessionTestHelper
  # Sign in via HTTP POST — exercises the full authentication flow.
  # Works in ActionDispatch::IntegrationTest (controller/integration tests).
  # Follows the post-login redirect automatically so subsequent requests
  # have the session cookie set.
  def sign_in_as(user, password: "password123")
    post session_path, params: {
      email_address: user.email_address,
      password: password
    }
    follow_redirect! if response.redirect?
  end

  def sign_out
    delete session_path
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
