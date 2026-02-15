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
end
