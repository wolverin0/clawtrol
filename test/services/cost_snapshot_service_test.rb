# frozen_string_literal: true

require "test_helper"

class CostSnapshotServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
  end

  # --- capture_daily ---

  test "capture_daily creates snapshot for yesterday" do
    assert_difference "CostSnapshot.count", 1 do
      CostSnapshotService.capture_daily(@user, date: Date.yesterday)
    end

    snap = CostSnapshot.last
    assert_equal "daily", snap.period
    assert_equal Date.yesterday, snap.snapshot_date
    assert_equal @user.id, snap.user_id
  end

  test "capture_daily is idempotent" do
    CostSnapshotService.capture_daily(@user, date: Date.yesterday)

    assert_no_difference "CostSnapshot.count" do
      CostSnapshotService.capture_daily(@user, date: Date.yesterday)
    end
  end

  test "capture_daily aggregates token_usages from the date" do
    task = @board.tasks.create!(
      name: "Test Task",
      status: :done,
      user: @user
    )

    TokenUsage.create!(
      task: task, model: "opus",
      input_tokens: 1000, output_tokens: 500, cost: 0.05,
      created_at: Date.yesterday.beginning_of_day + 12.hours
    )

    TokenUsage.create!(
      task: task, model: "codex",
      input_tokens: 2000, output_tokens: 1000, cost: 0.02,
      created_at: Date.yesterday.beginning_of_day + 14.hours
    )

    # Outside range (today) — should NOT be included
    TokenUsage.create!(
      task: task, model: "opus",
      input_tokens: 5000, output_tokens: 2500, cost: 0.50,
      created_at: Time.current
    )

    CostSnapshotService.capture_daily(@user, date: Date.yesterday)

    snap = CostSnapshot.last
    assert_equal 3000, snap.total_input_tokens  # 1000 + 2000
    assert_equal 1500, snap.total_output_tokens  # 500 + 1000
    assert_equal 2, snap.api_calls
    assert snap.cost_by_model.key?("opus")
    assert snap.cost_by_model.key?("codex")
  end

  # --- capture_weekly ---

  test "capture_weekly creates snapshot for previous week" do
    date = Date.current.beginning_of_week - 1.week

    assert_difference "CostSnapshot.count", 1 do
      CostSnapshotService.capture_weekly(@user, date: date)
    end

    snap = CostSnapshot.last
    assert_equal "weekly", snap.period
    assert_equal date.beginning_of_week, snap.snapshot_date
  end

  # --- capture_monthly ---

  test "capture_monthly creates snapshot for previous month" do
    date = Date.current.prev_month

    assert_difference "CostSnapshot.count", 1 do
      CostSnapshotService.capture_monthly(@user, date: date)
    end

    snap = CostSnapshot.last
    assert_equal "monthly", snap.period
    assert_equal date.beginning_of_month, snap.snapshot_date
  end

  # --- capture_all ---

  test "capture_all creates snapshots for all users" do
    user_count = User.count
    date = 100.days.ago.to_date

    assert_difference "CostSnapshot.count", user_count do
      CostSnapshotService.capture_all(date: date)
    end
  end

  # --- budget inheritance ---

  test "new snapshot inherits budget_limit from previous snapshot" do
    CostSnapshot.create!(
      user: @user, period: "daily", snapshot_date: 3.days.ago.to_date,
      total_cost: 1.0, budget_limit: 5.00,
      total_input_tokens: 0, total_output_tokens: 0, api_calls: 0
    )

    CostSnapshotService.capture_daily(@user, date: 2.days.ago.to_date)

    snap = CostSnapshot.where(user: @user, period: "daily", snapshot_date: 2.days.ago.to_date).first
    assert_not_nil snap
    assert_equal 5.00, snap.budget_limit.to_f
  end

  # --- cost_by_source ---

  test "cost_by_source includes task labels" do
    task = @board.tasks.create!(
      name: "Expensive Task",
      status: :done,
      user: @user
    )

    TokenUsage.create!(
      task: task, model: "opus",
      input_tokens: 10_000, output_tokens: 5_000, cost: 1.23,
      created_at: Date.yesterday.beginning_of_day + 10.hours
    )

    CostSnapshotService.capture_daily(@user, date: Date.yesterday)

    snap = CostSnapshot.last
    assert snap.cost_by_source.present?
    assert snap.cost_by_source.keys.any? { |k| k.include?("Expensive Task") }
  end

  # --- tokens_by_model ---

  test "tokens_by_model has correct structure" do
    task = @board.tasks.create!(
      name: "Token Test",
      status: :done,
      user: @user
    )

    TokenUsage.create!(
      task: task, model: "gemini",
      input_tokens: 3000, output_tokens: 1500, cost: 0.0,
      created_at: Date.yesterday.beginning_of_day + 8.hours
    )

    CostSnapshotService.capture_daily(@user, date: Date.yesterday)

    snap = CostSnapshot.last
    assert snap.tokens_by_model.key?("gemini")
    assert_equal 3000, snap.tokens_by_model["gemini"]["input"]
    assert_equal 1500, snap.tokens_by_model["gemini"]["output"]
  end
end
