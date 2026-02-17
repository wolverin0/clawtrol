# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
  end

  # --- Validations ---

  test "valid user" do
    user = User.new(email_address: "fresh@example.com", password: "password123", password_confirmation: "password123")
    assert user.valid?, "Expected valid: #{user.errors.full_messages}"
  end

  test "email is required" do
    user = User.new(email_address: nil, password: "password123", password_confirmation: "password123")
    assert_not user.valid?
    assert user.errors[:email_address].any?
  end

  test "email must be unique (case-insensitive)" do
    User.create!(email_address: "unique@example.com", password: "password123", password_confirmation: "password123")
    dup = User.new(email_address: "Unique@Example.com", password: "password123", password_confirmation: "password123")
    assert_not dup.valid?
    assert_includes dup.errors[:email_address], "has already been taken"
  end

  test "email must be valid format" do
    user = User.new(email_address: "not-an-email", password: "password123", password_confirmation: "password123")
    assert_not user.valid?
    assert user.errors[:email_address].any?
  end

  test "password minimum length" do
    user = User.new(email_address: "short@example.com", password: "short", password_confirmation: "short")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "password confirmation must match" do
    user = User.new(email_address: "mismatch@example.com", password: "password123", password_confirmation: "different123")
    assert_not user.valid?
    assert user.errors[:password_confirmation].any?
  end

  test "theme must be in THEMES" do
    @user.theme = "invalid_theme"
    assert_not @user.valid?
    assert @user.errors[:theme].any?
  end

  test "default and vaporwave themes are valid" do
    %w[default vaporwave].each do |theme|
      @user.theme = theme
      assert @user.valid?, "Expected theme '#{theme}' to be valid"
    end
  end

  # --- Webhook URL SSRF prevention ---

  test "webhook url rejects localhost" do
    @user.webhook_notification_url = "http://localhost:3000/hook"
    assert_not @user.valid?
    assert_includes @user.errors[:webhook_notification_url].join, "internal/private"
  end

  test "webhook url rejects 127.0.0.1" do
    @user.webhook_notification_url = "http://127.0.0.1:8080/hook"
    assert_not @user.valid?
    assert_includes @user.errors[:webhook_notification_url].join, "internal/private"
  end

  test "webhook url rejects 192.168.x.x" do
    @user.webhook_notification_url = "http://192.168.1.1/hook"
    assert_not @user.valid?
    assert_includes @user.errors[:webhook_notification_url].join, "internal/private"
  end

  test "webhook url rejects 10.x.x.x" do
    @user.webhook_notification_url = "http://10.0.0.1/hook"
    assert_not @user.valid?
    assert_includes @user.errors[:webhook_notification_url].join, "internal/private"
  end

  test "webhook url rejects .internal TLD" do
    @user.webhook_notification_url = "http://db.internal/hook"
    assert_not @user.valid?
    assert_includes @user.errors[:webhook_notification_url].join, "internal/private"
  end

  test "webhook url accepts public URLs" do
    @user.webhook_notification_url = "https://hooks.example.com/notify"
    assert @user.valid?, "Expected public webhook URL to be valid: #{@user.errors.full_messages}"
  end

  test "webhook url rejects non-HTTP schemes" do
    @user.webhook_notification_url = "ftp://files.example.com"
    assert_not @user.valid?
    assert @user.errors[:webhook_notification_url].any?
  end

  # --- Instance methods ---

  test "email normalization strips and downcases" do
    user = User.new(email_address: "  UPPER@Example.COM  ", password: "password123", password_confirmation: "password123")
    assert_equal "upper@example.com", user.email_address
  end

  test "has_avatar? returns false without avatar" do
    assert_not @user.has_avatar? unless @user.avatar.attached? || @user.avatar_url.present?
  end

  test "oauth_user? returns false for password users" do
    assert_not @user.oauth_user? if @user.provider.blank?
  end

  test "password_user? returns true when password_digest present" do
    assert @user.password_user? if @user.password_digest.present?
  end

  # --- Constants ---

  test "THEMES constant" do
    assert_equal %w[default vaporwave], User::THEMES
  end

  # --- Scopes ---

  test "admins scope returns only admin users" do
    admin = User.create!(email_address: "admin#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", admin: true)
    non_admin = User.create!(email_address: "user#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", admin: false)

    assert_includes User.admins, admin
    assert_not_includes User.admins, non_admin
  end

  test "active_users scope returns only active users" do
    active = User.create!(email_address: "active#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", active: true)
    inactive = User.create!(email_address: "inactive#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", active: false)

    assert_includes User.active_users, active
    assert_not_includes User.active_users, inactive
  end

  test "by_email scope is case insensitive" do
    user = User.create!(email_address: "testemail#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123")

    assert_includes User.by_email(user.email_address.downcase), user
    assert_includes User.by_email(user.email_address.upcase), user
  end
end
