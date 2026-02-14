# frozen_string_literal: true

require "test_helper"

class FactoryCycleLogTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @loop = FactoryLoop.create!(
      name: "Test Loop",
      slug: "fcl-test-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "minimax",
      status: "idle",
      user: @user,
      openclaw_cron_id: "cron-#{SecureRandom.hex(4)}",
    )
  end

  def build_log(attrs = {})
    FactoryCycleLog.new({
      factory_loop: @loop,
      cycle_number: 1,
      started_at: Time.current,
      status: "completed"
    }.merge(attrs))
  end

  # --- Validations ---
  test "valid with required fields" do
    log = build_log
    assert log.valid?
  end

  test "requires cycle_number" do
    log = build_log(cycle_number: nil)
    assert_not log.valid?
  end

  test "requires started_at" do
    log = build_log(started_at: nil)
    assert_not log.valid?
  end

  test "requires status" do
    log = build_log(status: nil)
    assert_not log.valid?
  end

  test "status must be in STATUSES" do
    log = build_log(status: "partying")
    assert_not log.valid?
  end

  test "validates all valid statuses" do
    FactoryCycleLog::STATUSES.each_with_index do |st, i|
      log = build_log(status: st, cycle_number: i + 10)
      assert log.valid?, "Expected status '#{st}' to be valid"
    end
  end

  test "cycle_number unique per loop" do
    build_log(cycle_number: 99).save!
    dup = build_log(cycle_number: 99)
    assert_not dup.valid?
  end

  test "cycle_number can repeat across loops" do
    other_loop = FactoryLoop.create!(
      name: "Other Loop",
      slug: "other-#{SecureRandom.hex(4)}",
      interval_ms: 30_000,
      model: "minimax",
      status: "idle",
      user: @user,
      openclaw_cron_id: "cron-#{SecureRandom.hex(4)}",
    )
    build_log(cycle_number: 1).save!
    other_log = FactoryCycleLog.new(
      factory_loop: other_loop,
      cycle_number: 1,
      started_at: Time.current,
      status: "completed"
    )
    assert other_log.valid?
  end

  # --- Scopes ---
  test "recent scope orders by created_at desc" do
    l1 = build_log(cycle_number: 1).tap(&:save!)
    l2 = build_log(cycle_number: 2).tap(&:save!)
    recent = @loop.factory_cycle_logs.recent
    assert_equal l2, recent.first
  end

  test "for_loop scope filters by loop" do
    build_log(cycle_number: 1).save!
    other = FactoryLoop.create!(
      name: "Other",
      slug: "scope-test-#{SecureRandom.hex(4)}",
      interval_ms: 30_000,
      model: "minimax",
      status: "idle",
      user: @user,
      openclaw_cron_id: "cron-#{SecureRandom.hex(4)}",
    )
    other.factory_cycle_logs.create!(cycle_number: 1, started_at: Time.current, status: "pending")

    assert_equal 1, FactoryCycleLog.for_loop(@loop.id).count
    assert_equal 1, FactoryCycleLog.for_loop(other.id).count
  end

  # --- Associations ---
  test "belongs_to factory_loop" do
    log = build_log
    log.save!
    assert_equal @loop, log.factory_loop
  end

  # --- Ignored columns ---
  test "errors column is ignored" do
    assert_includes FactoryCycleLog.ignored_columns, "errors"
  end
end
