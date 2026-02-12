require "test_helper"

class WorkflowDefinitionValidatorTest < ActiveSupport::TestCase
  test "validates and sorts simple DAG" do
    defn = {
      "nodes" => [
        { "id" => "a", "type" => "trigger" },
        { "id" => "b", "type" => "agent" },
        { "id" => "c", "type" => "tool" }
      ],
      "edges" => [
        { "from" => "a", "to" => "b" },
        { "from" => "b", "to" => "c" }
      ]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal %w[a b c], res.order
  end

  test "rejects cycles" do
    defn = {
      "nodes" => [
        { "id" => "a", "type" => "trigger" },
        { "id" => "b", "type" => "agent" }
      ],
      "edges" => [
        { "from" => "a", "to" => "b" },
        { "from" => "b", "to" => "a" }
      ]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert_includes res.errors.join(" "), "cycle"
  end
end
