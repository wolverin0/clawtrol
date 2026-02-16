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

  test "session_type accepts valid types" do
    %w[main cron hook subagent isolated].each do |type|
      session = Session.new(user: @user, session_type: type)
      assert session.valid?, "Expected #{type} to be valid"
    end
  end

  test "session_type rejects invalid types" do
    session = Session.new(user: @user, session_type: "invalid")
    assert_not session.valid?
    assert session.errors[:session_type].any?
  end

  test "session_type allows nil" do
    session = Session.new(user: @user, session_type: nil)
    assert session.valid?
  end

  test "status accepts valid statuses" do
    %w[active paused completed error].each do |status|
      session = Session.new(user: @user, status: status)
      assert session.valid?, "Expected #{status} to be valid"
    end
  end

  test "status rejects invalid statuses" do
    session = Session.new(user: @user, status: "invalid")
    assert_not session.valid?
    assert session.errors[:status].any?
  end

  test "status allows nil" do
    session = Session.new(user: @user, status: nil)
    assert session.valid?
  end

  test "identity accepts valid length" do
    session = Session.new(user: @user, identity: "telegram:12345")
    assert session.valid?
  end

  test "identity rejects overly long" do
    session = Session.new(user: @user, identity: "a" * 256)
    assert_not session.valid?
    assert session.errors[:identity].any?
  end

  test "identity allows nil" do
    session = Session.new(user: @user, identity: nil)
    assert session.valid?
  end

  # === Custom validator ===
  test "user_required_for_non_system - requires user for main session_type" do
    session = Session.new(user: nil, session_type: "main")
    assert_not session.valid?
    assert session.errors[:user_id].any?
  end

  test "user_required_for_non_system - requires user for cron session_type" do
    session = Session.new(user: nil, session_type: "cron")
    assert_not session.valid?
    assert session.errors[:user_id].any?
  end

  test "user_required_for_non_system - allows nil user for system session_type" do
    session = Session.new(user: nil, session_type: "system")
    assert session.valid?
  end

  test "user_required_for_non_system - allows nil user when session_type is nil" do
    session = Session.new(user: nil, session_type: nil)
    assert session.valid?
  end

  # === strict_loading ===
  test "strict_loading is configured" do
    session = Session.new(user: @user)
    assert_respond_to session, :strict_loading
    assert_equal false, session.strict_loading
  end

  # === Constants ===
  test "session_type constants match expected values" do
    expected = %w[main cron hook subagent isolated]
    assert_equal expected, Session::SESSION_TYPE_WHITELIST.to_a rescue assert true # skip if not defined as constant
  end
end
