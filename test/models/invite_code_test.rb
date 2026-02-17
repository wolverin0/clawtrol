# frozen_string_literal: true

require "test_helper"

class InviteCodeTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
  end

  # --- Validations ---

  test "valid invite code" do
    code = InviteCode.new(created_by: @user)
    assert code.valid?, "Expected fresh invite code to be valid: #{code.errors.full_messages}"
  end

  test "auto-generates code on create" do
    code = InviteCode.create!(created_by: @user)
    assert code.code.present?
    assert_match(/\A[A-Z0-9]{8}\z/, code.code)
  end

  test "code must be unique" do
    code1 = InviteCode.create!(created_by: @user)
    code2 = InviteCode.new(created_by: @user, code: code1.code)
    assert_not code2.valid?
    assert_includes code2.errors[:code], "has already been taken"
  end

  test "email validation allows blank" do
    code = InviteCode.new(created_by: @user, email: "")
    assert code.valid?
  end

  test "email validation rejects invalid format" do
    code = InviteCode.new(created_by: @user, email: "not-an-email")
    assert_not code.valid?
    assert code.errors[:email].any?
  end

  test "email validation accepts valid email" do
    code = InviteCode.new(created_by: @user, email: "test@example.com")
    assert code.valid?
  end

  # --- Scopes ---

  test "available scope returns unused codes" do
    used = InviteCode.create!(created_by: @user, used_at: Time.current)
    available = InviteCode.create!(created_by: @user)
    assert_includes InviteCode.available, available
    assert_not_includes InviteCode.available, used
  end

  test "used scope returns redeemed codes" do
    used = InviteCode.create!(created_by: @user, used_at: Time.current)
    available = InviteCode.create!(created_by: @user)
    assert_includes InviteCode.used, used
    assert_not_includes InviteCode.used, available
  end

  # --- Instance methods ---

  test "available? returns true when not redeemed" do
    code = InviteCode.create!(created_by: @user)
    assert code.available?
  end

  test "available? returns false when redeemed" do
    code = InviteCode.create!(created_by: @user, used_at: Time.current)
    assert_not code.available?
  end

  test "redeem! sets used_at and email" do
    code = InviteCode.create!(created_by: @user)
    assert code.available?

    code.redeem!("newuser@example.com")
    code.reload

    assert_not code.available?
    assert_equal "newuser@example.com", code.email
    assert code.used_at.present?
  end

  test "redeem! uses existing email if none provided" do
    code = InviteCode.create!(created_by: @user, email: "preset@example.com")
    code.redeem!
    code.reload

    assert_equal "preset@example.com", code.email
  end

  # --- More validation edge cases ---

  test "code must be exactly 8 characters" do
    code = InviteCode.new(created_by: @user, code: "ABC12345") # 8 chars - valid
    assert code.valid?

    code2 = InviteCode.new(created_by: @user, code: "ABC1234") # 7 chars
    assert_not code2.valid?
    assert_includes code2.errors[:code], "is the wrong length"
  end

  test "code must be alphanumeric uppercase" do
    code = InviteCode.new(created_by: @user, code: "ABCD1234") # valid
    assert code.valid?

    code2 = InviteCode.new(created_by: @user, code: "abcd1234") # lowercase
    assert_not code2.valid?

    code3 = InviteCode.new(created_by: @user, code: "ABCD-234") # hyphen
    assert_not code3.valid?
  end

  test "role inclusion validation" do
    code = InviteCode.new(created_by: @user, role: "admin")
    assert code.valid?

    code2 = InviteCode.new(created_by: @user, role: "superadmin")
    assert_not code2.valid?
  end

  test "role can be nil" do
    code = InviteCode.new(created_by: @user, role: nil)
    assert code.valid?
  end

  test "role length maximum is 50" do
    code = InviteCode.new(created_by: @user, role: "a" * 51)
    assert_not code.valid?
  end

  test "max_uses must be positive integer" do
    code = InviteCode.new(created_by: @user, max_uses: 1)
    assert code.valid?

    code2 = InviteCode.new(created_by: @user, max_uses: 0)
    assert_not code2.valid?

    code3 = InviteCode.new(created_by: @user, max_uses: -1)
    assert_not code3.valid?
  end

  test "max_uses maximum is 1000" do
    code = InviteCode.new(created_by: @user, max_uses: 1000)
    assert code.valid?

    code2 = InviteCode.new(created_by: @user, max_uses: 1001)
    assert_not code2.valid?
  end

  test "max_uses can be nil" do
    code = InviteCode.new(created_by: @user, max_uses: nil)
    assert code.valid?
  end

  test "expires_at validation rejects past dates" do
    code = InviteCode.new(created_by: @user, expires_at: 1.day.ago)
    assert_not code.valid?
    assert_includes code.errors[:expires_at], "must be in the future"
  end

  test "expires_at can be in the future" do
    code = InviteCode.new(created_by: @user, expires_at: 1.day.from_now)
    assert code.valid?
  end

  test "expires_at can be nil" do
    code = InviteCode.new(created_by: @user, expires_at: nil)
    assert code.valid?
  end

  # --- Association ---

  test "belongs_to created_by user" do
    code = InviteCode.create!(created_by: @user)
    assert_equal @user, code.created_by
  end

  test "inverse_of is set correctly" do
    code = InviteCode.create!(created_by: @user)
    assert_includes @user.invite_codes, code
  end
end
