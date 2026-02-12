require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  test "valid fixture" do
    assert workflows(:one).valid?
  end

  test "requires title" do
    w = Workflow.new(title: "", definition: {})
    assert_not w.valid?
    assert_includes w.errors[:title], "can't be blank"
  end

  test "definition must be a hash" do
    w = Workflow.new(title: "X", definition: "not a hash")
    assert_not w.valid?
    assert_includes w.errors[:definition], "must be a JSON object"
  end
end
