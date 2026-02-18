# frozen_string_literal: true

require "test_helper"

class BoardRoadmapTaskGeneratorTest < ActiveSupport::TestCase
  setup do
    @board = boards(:one)
    @roadmap = BoardRoadmap.create!(
      board: @board,
      body: <<~MD
        # Plan
        - [ ] First task
        - [x] completed
        - [ ]   Second task
        - [ ] First task
      MD
    )
  end

  test "parses unchecked checklist items" do
    items = @roadmap.unchecked_items

    assert_equal ["First task", "Second task"], items.map { |item| item[:text] }
    assert items.all? { |item| item[:key].present? }
  end

  test "generation creates tasks for unchecked items" do
    result = BoardRoadmapTaskGenerator.new(@roadmap).call

    assert_equal 2, result.created_count
    assert_equal 2, @roadmap.task_links.count
    assert_equal ["First task", "Second task"].sort,
                 result.created_tasks.map(&:name).sort
    assert result.created_tasks.all? { |task| task.board_id == @board.id }
  end

  test "generation is idempotent" do
    first = BoardRoadmapTaskGenerator.new(@roadmap).call
    second = BoardRoadmapTaskGenerator.new(@roadmap).call

    assert_equal 2, first.created_count
    assert_equal 0, second.created_count
    assert_equal 2, @roadmap.task_links.count
  end
end
