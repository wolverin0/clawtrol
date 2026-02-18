# frozen_string_literal: true

require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
  end

  # === Basic validations ===
  test "valid with user" do
    session = Session.new(user: @user)
    assert session.valid?
  end

  test "belongs_to user" do
    session = Session.create!(user: @user)
    assert_equal @user, session.user
  end

  # === Scopes ===
  test "scope for_user scopes by user" do
    session1 = Session.create!(user: @user)
    user2 = User.create!(email_address: "other@test.com", password: "password123456")
    session2 = Session.create!(user: user2)

    assert_includes Session.for_user(@user), session1
    assert_not_includes Session.for_user(@user), session2
  end

  test "scope recent orders by created_at" do
    session_old = Session.create!(user: @user)
    session_new = Session.create!(user: @user)

    assert_equal [session_new.id, session_old.id], Session.recent.ids
  end

  # === Validations ===
  test "ip_address accepts valid length" do
    session = Session.new(user: @user, ip_address: "192.168.1.1")
    assert session.valid?
  end

  test "user_agent accepts valid length" do
    session = Session.new(user: @user, user_agent: "Mozilla/5.0 (Test)")
    assert session.valid?
  end

  test "ip_address rejects overly long" do
    session = Session.new(user: @user, ip_address: "a" * 256)
    assert_not session.valid?
    assert session.errors[:ip_address].any?
  end

  test "user_agent rejects overly long" do
    session = Session.new(user: @user, user_agent: "a" * 501)
    assert_not session.valid?
    assert session.errors[:user_agent].any?
  end
end
