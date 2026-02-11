require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "ordered_for_column sorts in_review by updated_at desc then id desc" do
    board = boards(:one)
    user = users(:one)
    tied_time = Time.zone.parse("2026-02-08 10:00:00")

    older = Task.create!(name: "older", board: board, user: user, status: :in_review, updated_at: tied_time - 5.minutes)
    tie_low_id = Task.create!(name: "tie-low", board: board, user: user, status: :in_review)
    tie_high_id = Task.create!(name: "tie-high", board: board, user: user, status: :in_review)

    tie_low_id.update_columns(updated_at: tied_time)
    tie_high_id.update_columns(updated_at: tied_time)

    ordered_ids = board.tasks.in_review.ordered_for_column(:in_review).pluck(:id)

    assert_equal [tie_high_id.id, tie_low_id.id, older.id], ordered_ids.first(3)
  end

  test "ordered_for_column sorts done by id desc" do
    board = boards(:one)
    user = users(:one)

    t1 = Task.create!(name: "done-1", board: board, user: user, status: :done)
    t2 = Task.create!(name: "done-2", board: board, user: user, status: :done)
    t3 = Task.create!(name: "done-3", board: board, user: user, status: :done)

    # Ensure other timestamps can't affect ordering
    t1.update_columns(completed_at: Time.zone.parse("2026-02-01 10:00:00"), updated_at: Time.zone.parse("2026-02-08 12:00:00"))
    t2.update_columns(completed_at: nil, updated_at: Time.zone.parse("2026-02-08 13:00:00"))
    t3.update_columns(completed_at: Time.zone.parse("2025-01-01 09:00:00"), updated_at: Time.zone.parse("2026-02-08 11:00:00"))

    ordered_ids = board.tasks.done.ordered_for_column(:done).pluck(:id)

    assert_equal [t3.id, t2.id, t1.id], ordered_ids.first(3)
  end

  test "try_auto_claim locks board to prevent concurrent claims" do
    board = boards(:one)
    user = users(:one)

    # Enable auto-claim with a rate limit window
    board.update_columns(auto_claim_enabled: true, last_auto_claim_at: nil)

    # First task should be auto-claimed
    t1 = Task.create!(name: "auto-1", board: board, user: user, status: :inbox)
    t1.reload
    assert_equal "up_next", t1.status, "First task should be auto-claimed to up_next"
    assert t1.assigned_to_agent?, "First task should be assigned to agent"

    # Board should now have a recent last_auto_claim_at, blocking the next claim
    board.reload
    assert_not_nil board.last_auto_claim_at, "Board should record auto-claim timestamp"

    # Second task created immediately should NOT be auto-claimed (rate limited)
    t2 = Task.create!(name: "auto-2", board: board, user: user, status: :inbox)
    t2.reload
    assert_equal "inbox", t2.status, "Second task should stay inbox (rate limited)"
    assert_not t2.assigned_to_agent?, "Second task should not be assigned"
  end

  test "try_auto_claim skips non-inbox tasks" do
    board = boards(:one)
    user = users(:one)
    board.update_columns(auto_claim_enabled: true, last_auto_claim_at: nil)

    task = Task.create!(name: "already progress", board: board, user: user, status: :up_next)
    task.reload
    # Should not have been double-promoted; status stays up_next
    assert_equal "up_next", task.status
  end

  test "assigned tasks cannot move to in_progress without a runner lease (or linked session)" do
    board = boards(:one)
    user = users(:one)

    task = Task.create!(name: "lease required", board: board, user: user, status: :up_next, assigned_to_agent: true)

    task.status = :in_progress
    assert_not task.valid?
    assert_includes task.errors[:status].join(" "), "Runner Lease"

    # Linked session counts as legacy evidence
    task.agent_session_id = "FAKE"
    assert task.valid?
  end
end
