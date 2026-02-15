# frozen_string_literal: true

require "test_helper"

class CostSnapshotTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # --- Validations ---

  test "valid snapshot with all required fields" do
    snap = CostSnapshot.new(
      user: @user,
      period: "daily",
      snapshot_date: Date.yesterday,
      total_cost: 1.5,
      total_input_tokens: 1000,
      total_output_tokens: 500,
      api_calls: 10
    )
    assert snap.valid?, snap.errors.full_messages.join(", ")
  end

  test "requires user" do
    snap = CostSnapshot.new(period: "daily", snapshot_date: Date.yesterday)
    assert_not snap.valid?
    assert_includes snap.errors[:user], "must exist"
  end

  test "requires snapshot_date" do
    snap = CostSnapshot.new(user: @user, period: "daily")
    assert_not snap.valid?
    assert_includes snap.errors[:snapshot_date], "can't be blank"
  end

  test "validates period inclusion" do
    snap = CostSnapshot.new(user: @user, period: "hourly", snapshot_date: Date.current)
    assert_not snap.valid?
    assert_includes snap.errors[:period], "is not included in the list"
  end

  test "validates total_cost non-negative" do
    snap = CostSnapshot.new(user: @user, period: "daily", snapshot_date: Date.current, total_cost: -1)
    assert_not snap.valid?
    assert_includes snap.errors[:total_cost], "must be greater than or equal to 0"
  end

  test "validates total_input_tokens non-negative integer" do
    snap = CostSnapshot.new(user: @user, period: "daily", snapshot_date: Date.current, total_input_tokens: -5)
    assert_not snap.valid?
    assert_includes snap.errors[:total_input_tokens], "must be greater than or equal to 0"
  end

  test "validates budget_limit must be positive when present" do
    snap = CostSnapshot.new(user: @user, period: "daily", snapshot_date: Date.current, budget_limit: 0)
    assert_not snap.valid?
    assert_includes snap.errors[:budget_limit], "must be greater than 0"
  end

  test "allows nil budget_limit" do
    snap = CostSnapshot.new(
      user: @user, period: "daily", snapshot_date: Date.current,
      total_cost: 0, total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    assert snap.valid?
  end

  test "prevents duplicate snapshot_date for same user and period" do
    CostSnapshot.create!(
      user: @user, period: "daily", snapshot_date: Date.yesterday,
      total_cost: 1.0, total_input_tokens: 100, total_output_tokens: 50, api_calls: 5
    )
    dup = CostSnapshot.new(
      user: @user, period: "daily", snapshot_date: Date.yesterday,
      total_cost: 2.0, total_input_tokens: 200, total_output_tokens: 100, api_calls: 10
    )
    assert_not dup.valid?
    assert_includes dup.errors[:snapshot_date], "already has a daily snapshot for this user"
  end

  test "allows same date for different periods" do
    CostSnapshot.create!(
      user: @user, period: "daily", snapshot_date: Date.yesterday,
      total_cost: 1.0, total_input_tokens: 100, total_output_tokens: 50, api_calls: 5
    )
    weekly = CostSnapshot.new(
      user: @user, period: "weekly", snapshot_date: Date.yesterday,
      total_cost: 7.0, total_input_tokens: 700, total_output_tokens: 350, api_calls: 35
    )
    assert weekly.valid?
  end

  # --- Instance methods ---

  test "total_tokens sums input and output" do
    snap = CostSnapshot.new(total_input_tokens: 1000, total_output_tokens: 500)
    assert_equal 1500, snap.total_tokens
  end

  test "budget_utilization returns nil without budget" do
    snap = CostSnapshot.new(total_cost: 5.0, budget_limit: nil)
    assert_nil snap.budget_utilization
  end

  test "budget_utilization calculates percentage" do
    snap = CostSnapshot.new(total_cost: 3.0, budget_limit: 10.0)
    assert_equal 30.0, snap.budget_utilization
  end

  test "budget_utilization handles over-budget" do
    snap = CostSnapshot.new(total_cost: 15.0, budget_limit: 10.0)
    assert_equal 150.0, snap.budget_utilization
  end

  test "top_model returns highest cost model" do
    snap = CostSnapshot.new(cost_by_model: { "opus" => 5.0, "codex" => 2.0, "gemini" => 0.1 })
    assert_equal "opus", snap.top_model
  end

  test "top_model returns nil for empty hash" do
    snap = CostSnapshot.new(cost_by_model: {})
    assert_nil snap.top_model
  end

  test "projected_monthly_cost for daily" do
    snap = CostSnapshot.new(period: "daily", total_cost: 2.0)
    assert_equal 60.0, snap.projected_monthly_cost
  end

  test "projected_monthly_cost for weekly" do
    snap = CostSnapshot.new(period: "weekly", total_cost: 14.0)
    assert_in_delta 60.0, snap.projected_monthly_cost, 0.01
  end

  test "projected_monthly_cost for monthly returns total_cost" do
    snap = CostSnapshot.new(period: "monthly", total_cost: 45.0)
    assert_equal 45.0, snap.projected_monthly_cost
  end

  # --- Callbacks ---

  test "check_budget_exceeded sets true when over budget" do
    snap = CostSnapshot.new(
      user: @user, period: "daily", snapshot_date: 3.days.ago.to_date,
      total_cost: 15.0, budget_limit: 10.0,
      total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    snap.save!
    assert snap.budget_exceeded
  end

  test "check_budget_exceeded sets false when under budget" do
    snap = CostSnapshot.new(
      user: @user, period: "daily", snapshot_date: 4.days.ago.to_date,
      total_cost: 5.0, budget_limit: 10.0,
      total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    snap.save!
    assert_not snap.budget_exceeded
  end

  test "check_budget_exceeded stays false without budget" do
    snap = CostSnapshot.new(
      user: @user, period: "daily", snapshot_date: 5.days.ago.to_date,
      total_cost: 100.0, budget_limit: nil,
      total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    snap.save!
    assert_not snap.budget_exceeded
  end

  # --- Scopes ---

  test "daily scope filters by period" do
    CostSnapshot.create!(
      user: @user, period: "daily", snapshot_date: 6.days.ago.to_date,
      total_cost: 1.0, total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    CostSnapshot.create!(
      user: @user, period: "weekly", snapshot_date: 6.days.ago.to_date,
      total_cost: 7.0, total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    assert_equal 1, CostSnapshot.for_user(@user).daily.count
  end

  test "over_budget scope" do
    CostSnapshot.create!(
      user: @user, period: "daily", snapshot_date: 7.days.ago.to_date,
      total_cost: 20.0, budget_limit: 10.0,
      total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    CostSnapshot.create!(
      user: @user, period: "daily", snapshot_date: 8.days.ago.to_date,
      total_cost: 5.0, budget_limit: 10.0,
      total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )
    assert_equal 1, CostSnapshot.for_user(@user).over_budget.count
  end

  # --- Class methods ---

  test "trend returns :flat with no data" do
    result = CostSnapshot.trend(user: @user, period: "daily", lookback: 7)
    assert_equal :flat, result
  end

  test "trend detects upward trend" do
    # Create ascending costs
    (1..7).each do |i|
      CostSnapshot.create!(
        user: @user, period: "daily", snapshot_date: (8 - i).days.ago.to_date,
        total_cost: i * 2.0,
        total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
      )
    end
    result = CostSnapshot.trend(user: @user, period: "daily", lookback: 7)
    assert_equal :up, result
  end

  test "summary returns empty hash with no data" do
    result = CostSnapshot.summary(user: @user, period: "monthly", days: 30)
    assert_equal({}, result)
  end
end
