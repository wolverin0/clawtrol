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
end
