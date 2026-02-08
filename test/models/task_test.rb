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

  test "ordered_for_column sorts done by completed_at desc nulls last, then updated_at desc, then id desc" do
    board = boards(:one)
    user = users(:one)
    tied_completed_time = Time.zone.parse("2026-02-08 11:00:00")

    completed_tie_older_update = Task.create!(name: "done-tie-older-update", board: board, user: user, status: :done)
    completed_tie_newer_update = Task.create!(name: "done-tie-newer-update", board: board, user: user, status: :done)
    completed_older = Task.create!(name: "done-older", board: board, user: user, status: :done)
    legacy_nil_completed_recent = Task.create!(name: "done-nil-completed-recent", board: board, user: user, status: :done)
    legacy_nil_completed_older = Task.create!(name: "done-nil-completed-older", board: board, user: user, status: :done)

    completed_tie_older_update.update_columns(completed_at: tied_completed_time, updated_at: tied_completed_time - 1.minute)
    completed_tie_newer_update.update_columns(completed_at: tied_completed_time, updated_at: tied_completed_time)
    completed_older.update_columns(completed_at: tied_completed_time - 5.minutes, updated_at: tied_completed_time - 5.minutes)

    legacy_nil_completed_recent.update_columns(completed_at: nil, updated_at: tied_completed_time + 10.minutes)
    legacy_nil_completed_older.update_columns(completed_at: nil, updated_at: tied_completed_time - 10.minutes)

    ordered_ids = board.tasks.done.ordered_for_column(:done).pluck(:id)

    assert_equal [
      completed_tie_newer_update.id,
      completed_tie_older_update.id,
      completed_older.id,
      legacy_nil_completed_recent.id,
      legacy_nil_completed_older.id
    ], ordered_ids.first(5)
  end
end
