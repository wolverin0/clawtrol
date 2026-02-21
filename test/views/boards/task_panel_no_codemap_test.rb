# frozen_string_literal: true

require "test_helper"

class Boards::TaskPanelNoCodemapTest < ActiveSupport::TestCase
  test "task panel does not render codemap widget" do
    source = File.read(Rails.root.join("app/views/boards/tasks/_panel.html.erb"))

    assert_not_includes source, "shared/codemap_widget"
  end
end
