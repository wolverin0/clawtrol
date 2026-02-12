require "test_helper"

class Boards::TaskPanelMobileScrollTest < ActiveSupport::TestCase
  test "task panel mobile evidence section has flex scroll-safe classes" do
    source = File.read(Rails.root.join("app/views/boards/tasks/_panel.html.erb"))

    # The mobile evidence section lives *outside* the main left-column scroll.
    # To ensure it can shrink within the flex container and become scrollable on
    # mobile, it must include `min-h-0` (flexbox scroll fix) + `overflow-y-auto`.
    assert_includes source, "lg:hidden px-5 py-4 border-t border-border"
    assert_includes source, "min-h-0"
    assert_includes source, "overflow-y-auto"
    assert_includes source, "overscroll-contain"
    assert_includes source, "-webkit-overflow-scrolling:touch"
  end
end
