# frozen_string_literal: true

require "test_helper"

class OpenclawMemoryIndicatorPartialTest < ActiveSupport::TestCase
  test "renders OK badge" do
    health = OpenclawMemorySearchHealthService::Result.new(status: :ok, last_checked_at: Time.current)

    html = ApplicationController.render(
      partial: "shared/openclaw_memory_indicator",
      locals: { health: health }
    )

    assert_includes html, "Memory: OK"
  end

  test "renders DOWN badge" do
    health = OpenclawMemorySearchHealthService::Result.new(status: :down, last_checked_at: Time.current, error_message: "boom")

    html = ApplicationController.render(
      partial: "shared/openclaw_memory_indicator",
      locals: { health: health }
    )

    assert_includes html, "Memory: DOWN"
    assert_includes html, "Suggested fixes"
  end

  test "does not render when status is unknown" do
    health = OpenclawMemorySearchHealthService::Result.new(status: :unknown)

    html = ApplicationController.render(
      partial: "shared/openclaw_memory_indicator",
      locals: { health: health }
    )

    assert_equal "", html.strip
  end
end
