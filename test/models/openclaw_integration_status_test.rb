# frozen_string_literal: true

require "test_helper"

class OpenclawIntegrationStatusTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Clean up any existing status for this user
    OpenclawIntegrationStatus.where(user: @user).delete_all
  end

  # --- Validations ---

  test "valid with user" do
    status = OpenclawIntegrationStatus.new(user: @user)
    assert status.valid?, "Expected valid: #{status.errors.full_messages}"
  end

  test "requires user" do
    status = OpenclawIntegrationStatus.new(user: nil)
    assert_not status.valid?
  end

  test "user_id must be unique" do
    OpenclawIntegrationStatus.create!(user: @user)
    duplicate = OpenclawIntegrationStatus.new(user: @user)
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  # --- Enum: memory_search_status ---

  test "default memory_search_status is unknown" do
    status = OpenclawIntegrationStatus.new(user: @user)
    assert_equal "unknown", status.memory_search_status
  end

  test "memory_search_status enum values" do
    expected = { "unknown" => 0, "ok" => 1, "degraded" => 2, "down" => 3 }
    assert_equal expected, OpenclawIntegrationStatus.memory_search_statuses
  end

  test "memory_search_ok? predicate works" do
    status = OpenclawIntegrationStatus.new(user: @user, memory_search_status: :ok)
    assert status.memory_search_ok?
    assert_not status.memory_search_unknown?
  end

  test "memory_search_degraded? predicate works" do
    status = OpenclawIntegrationStatus.new(user: @user, memory_search_status: :degraded)
    assert status.memory_search_degraded?
  end

  test "memory_search_down? predicate works" do
    status = OpenclawIntegrationStatus.new(user: @user, memory_search_status: :down)
    assert status.memory_search_down?
  end

  # --- Associations ---

  test "belongs to user" do
    status = OpenclawIntegrationStatus.create!(user: @user)
    assert_equal @user, status.user
  end

  # --- Error tracking ---

  test "stores memory_search_last_error" do
    status = OpenclawIntegrationStatus.create!(
      user: @user,
      memory_search_status: :down,
      memory_search_last_error: "Connection refused",
      memory_search_last_error_at: Time.current
    )
    status.reload
    assert_equal "Connection refused", status.memory_search_last_error
    assert_not_nil status.memory_search_last_error_at
  end

  test "stores memory_search_last_checked_at" do
    now = Time.current
    status = OpenclawIntegrationStatus.create!(
      user: @user,
      memory_search_last_checked_at: now
    )
    status.reload
    assert_in_delta now, status.memory_search_last_checked_at, 1.second
  end
end
