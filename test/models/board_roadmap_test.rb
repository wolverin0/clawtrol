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
