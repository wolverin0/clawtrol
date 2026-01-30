require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid params creates user and logs in" do
    assert_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to projects_path
    assert cookies[:session_id]
    assert User.find_by(email_address: "newuser@example.com")
  end

  test "create with mismatched passwords shows error" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "differentpassword"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with short password shows error" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with existing email shows error" do
    existing_user = users(:one)

    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
