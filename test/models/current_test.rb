# frozen_string_literal: true

require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  # Current is an ActiveSupport::CurrentAttributes class
  # It provides thread-local access to session and user

  test "Current can be assigned a session" do
    user = users(:default)
    session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "Test Agent"
    )

    Current.session = session

    assert_equal session, Current.session
  end

  test "Current.user delegates to session" do
    user = users(:default)
    session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "Test Agent"
    )

    Current.session = session

    assert_equal user, Current.user
  end

  test "Current.user returns nil when session is nil" do
    Current.session = nil

    assert_nil Current.user
  end

  test "Current.user returns nil when session is set to nil explicitly" do
    user = users(:default)
    session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "Test Agent"
    )

    Current.session = session
    assert_equal user, Current.user

    Current.session = nil
    assert_nil Current.user
  end

  test "Current allows_nil on session" do
    # Should not raise when setting to nil
    assert_nothing_raised do
      Current.session = nil
    end

    assert_nil Current.session
  end
end
