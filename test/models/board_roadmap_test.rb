# frozen_string_literal: true

require "test_helper"

class BoardRoadmapTest < ActiveSupport::TestCase
  test "unchecked_items parses markdown checkboxes across common list markers" do
    roadmap = BoardRoadmap.new(
      board: boards(:one),
      body: <<~MD
        - [ ] Ship dashboard widget
        * [ ] Add API endpoint
        + [ ] Write docs
        1. [ ] Verify release
      MD
    )

    assert_equal [
      "Ship dashboard widget",
      "Add API endpoint",
      "Write docs",
      "Verify release"
    ], roadmap.unchecked_items.map { |item| item[:text] }
  end

  test "checked_items parses completed checkboxes" do
    roadmap = BoardRoadmap.new(
      board: boards(:one),
      body: <<~MD
        - [x] Done item one
        - [X] Done item two
        - [ ] Not done yet
        * [x] Also done
      MD
    )

    items = roadmap.checked_items
    assert_equal 3, items.size
    assert_equal ["Done item one", "Done item two", "Also done"], items.map { |i| i[:text] }
  end

  test "progress_summary returns X/Y format" do
    roadmap = BoardRoadmap.new(
      board: boards(:one),
      body: "- [x] Done\n- [ ] Pending\n- [x] Also done\n- [ ] Another pending"
    )

    assert_equal "2/4", roadmap.progress_summary
  end

  test "progress_summary returns nil when no checklist items" do
    roadmap = BoardRoadmap.new(board: boards(:one), body: "Just some notes")
    assert_nil roadmap.progress_summary
  end

  test "unchecked_items ignores checked items and deduplicates by normalized text" do
    roadmap = BoardRoadmap.new(
      board: boards(:one),
      body: <<~MD
        - [x] Already done
        - [ ]  Ship dashboard widget
        * [ ] ship   dashboard   widget
      MD
    )

    items = roadmap.unchecked_items

    assert_equal 1, items.size
    assert_equal "Ship dashboard widget", items.first[:text]
  end
end
