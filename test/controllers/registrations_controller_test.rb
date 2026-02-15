# frozen_string_literal: true

require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Registration requires ALLOW_REGISTRATION=true and a valid invite code
    ENV["ALLOW_REGISTRATION"] = "true"
    @invite = InviteCode.create!(code: "TESTCODE", created_by: users(:one))
  end

  teardown do
    ENV.delete("ALLOW_REGISTRATION")
  end

  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid params creates user and logs in" do
    assert_difference("User.count") do
      post registration_path, params: {
        invite_code: @invite.code,
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to boards_path
  end

  test "create with mismatched passwords shows error" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        invite_code: @invite.code,
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
        invite_code: @invite.code,
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
        invite_code: @invite.code,
        user: {
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create without invite code fails" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "redirects when registration disabled" do
    ENV["ALLOW_REGISTRATION"] = "false"
    get new_registration_path
    assert_redirected_to new_session_path
  end
end
