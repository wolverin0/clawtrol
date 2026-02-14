# frozen_string_literal: true

require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
  end

  test "valid with user" do
    session = Session.new(user: @user)
    assert session.valid?
  end

  test "requires user" do
    session = Session.new(user: nil)
    assert_not session.valid?
  end

  test "belongs_to user" do
    session = Session.create!(user: @user)
    assert_equal @user, session.user
  end
end
