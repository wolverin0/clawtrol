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

  test "allows nil definition (defaults to empty hash)" do
    w = Workflow.new(title: "Test", user: users(:one))
    assert w.valid?
    assert_equal({}, w.definition)
  end

  test "belongs to user optionally" do
    w = Workflow.new(title: "Global", definition: {})
    assert w.valid?, "Workflow should be valid without user"
  end

  test "belongs to user when set" do
    w = Workflow.new(title: "User-owned", definition: {}, user: users(:one))
    assert w.valid?
    assert_equal users(:one), w.user
  end

  # --- Scopes ---

  test "for_user includes user's workflows" do
    user = users(:one)
    w = Workflow.create!(title: "Mine", definition: {}, user: user)

    results = Workflow.for_user(user)
    assert_includes results, w
  end

  test "for_user includes global workflows (nil user_id)" do
    user = users(:one)
    global = Workflow.create!(title: "Global", definition: {}, user: nil)

    results = Workflow.for_user(user)
    assert_includes results, global
  end

  test "for_user excludes other user's workflows" do
    user_one = users(:one)
    user_two = users(:two)
    other_w = Workflow.create!(title: "Other's", definition: {}, user: user_two)

    results = Workflow.for_user(user_one)
    assert_not_includes results, other_w
  end

  # --- Definition validation edge cases ---

  test "accepts complex hash definition" do
    definition = {
      "nodes" => [
        { "id" => "start", "type" => "trigger" },
        { "id" => "end", "type" => "output" }
      ],
      "edges" => [{ "from" => "start", "to" => "end" }]
    }
    w = Workflow.new(title: "Complex", definition: definition, user: users(:one))
    assert w.valid?
  end

  test "rejects array definition" do
    w = Workflow.new(title: "Array", definition: [1, 2, 3])
    assert_not w.valid?
    assert_includes w.errors[:definition], "must be a JSON object"
  end

  test "rejects integer definition" do
    w = Workflow.new(title: "Int", definition: 42)
    assert_not w.valid?
    assert_includes w.errors[:definition], "must be a JSON object"
  end

  # --- Active flag ---

  test "defaults to inactive" do
    w = Workflow.create!(title: "New one", definition: {}, user: users(:one))
    assert_equal false, w.active
  end

  test "can be activated" do
    w = Workflow.create!(title: "Activate me", definition: {}, user: users(:one))
    w.update!(active: true)
    assert w.reload.active?
  end
end
