# frozen_string_literal: true

require "test_helper"

class Boards::TaskCardBadgesVisibilityTest < ActiveSupport::TestCase
  test "task card badges are not hidden behind hover-only opacity classes" do
    task = Task.create!(
      name: "Badge visibility test",
      user: users(:one),
      board: boards(:one),
      status: :inbox,
      priority: :none,
      model: "opus",
      nightly: true
    )

    html = ApplicationController.render(
      partial: "boards/task_card",
      locals: { task: task }
    )

    assert_includes html, "OPUS"
    assert_includes html, "nightly-badge"
    assert_not_includes html, "opacity-0 group-hover:opacity-100"
  end
end
