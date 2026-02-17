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

  # --- Scopes ---

  test "active scope excludes down statuses" do
    ok_status = OpenclawIntegrationStatus.create!(user: @user, memory_search_status: :ok)
    down_status = OpenclawIntegrationStatus.create!(user: users(:two), memory_search_status: :down)

    assert_includes OpenclawIntegrationStatus.active, ok_status
    assert_not_includes OpenclawIntegrationStatus.active, down_status
  end

  test "degraded scope returns only degraded" do
    degraded = OpenclawIntegrationStatus.create!(user: @user, memory_search_status: :degraded)
    ok = OpenclawIntegrationStatus.create!(user: users(:two), memory_search_status: :ok)

    assert_includes OpenclawIntegrationStatus.degraded, degraded
    assert_not_includes OpenclawIntegrationStatus.degraded, ok
  end

  test "ok_status scope returns only ok" do
    ok = OpenclawIntegrationStatus.create!(user: @user, memory_search_status: :ok)
    degraded = OpenclawIntegrationStatus.create!(user: users(:two), memory_search_status: :degraded)

    assert_includes OpenclawIntegrationStatus.ok_status, ok
    assert_not_includes OpenclawIntegrationStatus.ok_status, degraded
  end

  # --- Edge cases ---

  test "memory_search_status accepts string value" do
    status = OpenclawIntegrationStatus.new(user: @user, memory_search_status: "ok")
    assert_equal "ok", status.memory_search_status
  end

  test "memory_search_status rejects invalid value" do
    status = OpenclawIntegrationStatus.new(user: @user, memory_search_status: "invalid")
    assert_not status.valid?
  end

  test "memory_search_last_error can be nil" do
    status = OpenclawIntegrationStatus.new(user: @user)
    assert_nil status.memory_search_last_error
  end

  test "memory_search_last_error_at can be nil" do
    status = OpenclawIntegrationStatus.new(user: @user)
    assert_nil status.memory_search_last_error_at
  end

  test "memory_search_last_checked_at can be nil" do
    status = OpenclawIntegrationStatus.new(user: @user)
    assert_nil status.memory_search_last_checked_at
  end

  test "all memory_search predicates return correct values" do
    status = OpenclawIntegrationStatus.new(user: @user, memory_search_status: :unknown)
    assert status.memory_search_unknown?
    assert_not status.memory_search_ok?
    assert_not status.memory_search_degraded?
    assert_not status.memory_search_down?
  end
end
