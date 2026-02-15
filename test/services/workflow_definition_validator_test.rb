# frozen_string_literal: true

require "test_helper"

class WorkflowDefinitionValidatorTest < ActiveSupport::TestCase
  # --- Happy path ---

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
    assert_equal 3, res.nodes.length
    assert_equal 2, res.edges.length
  end

  test "validates DAG with parallel branches" do
    defn = {
      "nodes" => [
        { "id" => "root", "type" => "trigger" },
        { "id" => "left", "type" => "agent" },
        { "id" => "right", "type" => "tool" },
        { "id" => "merge", "type" => "notification" }
      ],
      "edges" => [
        { "from" => "root", "to" => "left" },
        { "from" => "root", "to" => "right" },
        { "from" => "left", "to" => "merge" },
        { "from" => "right", "to" => "merge" }
      ]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal "root", res.order.first
    assert_equal "merge", res.order.last
  end

  test "validates single node with no edges" do
    defn = {
      "nodes" => [{ "id" => "solo", "type" => "trigger" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal %w[solo], res.order
  end

  test "accepts all valid node types" do
    types = %w[trigger agent tool router nightshift conditional notification delay]
    nodes = types.each_with_index.map { |t, i| { "id" => "n#{i}", "type" => t } }

    res = WorkflowDefinitionValidator.validate("nodes" => nodes, "edges" => [])
    assert res.ok?
    assert_equal types.length, res.nodes.length
  end

  test "accepts symbol keys" do
    defn = {
      nodes: [
        { id: "a", type: "trigger" },
        { id: "b", type: "agent" }
      ],
      edges: [
        { from: "a", to: "b" }
      ]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal %w[a b], res.order
  end

  # --- Node normalisation ---

  test "normalizes type to lowercase" do
    defn = {
      "nodes" => [{ "id" => "x", "type" => "AGENT" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal "agent", res.nodes.first["type"]
  end

  test "defaults props to empty hash when missing" do
    defn = {
      "nodes" => [{ "id" => "x", "type" => "trigger" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal({}, res.nodes.first["props"])
  end

  test "preserves node props" do
    defn = {
      "nodes" => [{ "id" => "x", "type" => "agent", "props" => { "model" => "opus" } }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok?
    assert_equal({ "model" => "opus" }, res.nodes.first["props"])
  end

  # --- Cycle detection ---

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

  test "rejects self-loop" do
    defn = {
      "nodes" => [{ "id" => "a", "type" => "trigger" }],
      "edges" => [{ "from" => "a", "to" => "a" }]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert_includes res.errors.join(" "), "cycle"
  end

  test "rejects indirect cycle" do
    defn = {
      "nodes" => [
        { "id" => "a", "type" => "trigger" },
        { "id" => "b", "type" => "agent" },
        { "id" => "c", "type" => "tool" }
      ],
      "edges" => [
        { "from" => "a", "to" => "b" },
        { "from" => "b", "to" => "c" },
        { "from" => "c", "to" => "a" }
      ]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert_includes res.errors.join(" "), "cycle"
  end

  # --- Invalid structure ---

  test "rejects non-hash definition" do
    res = WorkflowDefinitionValidator.validate("not a hash")
    assert_not res.ok?
    assert_includes res.errors.join(" "), "JSON object"
  end

  test "rejects nil definition" do
    res = WorkflowDefinitionValidator.validate(nil)
    assert_not res.ok?
  end

  # --- Node validation errors ---

  test "rejects nodes with blank id" do
    defn = {
      "nodes" => [{ "id" => "", "type" => "trigger" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("id") }
  end

  test "rejects duplicate node ids" do
    defn = {
      "nodes" => [
        { "id" => "dup", "type" => "trigger" },
        { "id" => "dup", "type" => "agent" }
      ],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("unique") }
  end

  test "rejects nodes with blank type" do
    defn = {
      "nodes" => [{ "id" => "x", "type" => "" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("type") }
  end

  test "rejects nodes with invalid type" do
    defn = {
      "nodes" => [{ "id" => "x", "type" => "banana" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("invalid type") }
  end

  test "rejects non-hash props" do
    defn = {
      "nodes" => [{ "id" => "x", "type" => "agent", "props" => "bad" }],
      "edges" => []
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("props") }
  end

  # --- Edge validation errors ---

  test "rejects edge with missing from" do
    defn = {
      "nodes" => [{ "id" => "a", "type" => "trigger" }],
      "edges" => [{ "from" => "", "to" => "a" }]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("from") }
  end

  test "rejects edge with missing to" do
    defn = {
      "nodes" => [{ "id" => "a", "type" => "trigger" }],
      "edges" => [{ "from" => "a", "to" => "" }]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("to") }
  end

  test "rejects edge referencing non-existent from node" do
    defn = {
      "nodes" => [{ "id" => "a", "type" => "trigger" }],
      "edges" => [{ "from" => "missing", "to" => "a" }]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("missing node") }
  end

  test "rejects edge referencing non-existent to node" do
    defn = {
      "nodes" => [{ "id" => "a", "type" => "trigger" }],
      "edges" => [{ "from" => "a", "to" => "missing" }]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.any? { |e| e.include?("missing node") }
  end

  # --- Edge cases ---

  test "handles empty nodes and edges" do
    res = WorkflowDefinitionValidator.validate("nodes" => [], "edges" => [])
    assert res.ok?
    assert_equal [], res.order
  end

  test "handles non-array nodes gracefully" do
    res = WorkflowDefinitionValidator.validate("nodes" => "bad", "edges" => [])
    # Should not crash — wraps in Array()
    assert res.ok? || res.errors.any?
  end

  test "handles non-array edges gracefully" do
    defn = {
      "nodes" => [{ "id" => "a", "type" => "trigger" }],
      "edges" => "bad"
    }
    res = WorkflowDefinitionValidator.validate(defn)
    assert res.ok? || res.errors.any?
  end

  test "accumulates multiple errors" do
    defn = {
      "nodes" => [
        { "id" => "", "type" => "banana" },
        { "id" => "", "type" => "" }
      ],
      "edges" => [{ "from" => "", "to" => "" }]
    }

    res = WorkflowDefinitionValidator.validate(defn)
    assert_not res.ok?
    assert res.errors.length > 1, "Expected multiple errors, got: #{res.errors}"
  end

  test "VALID_TYPES constant has expected types" do
    expected = %w[trigger agent tool router nightshift conditional notification delay]
    assert_equal expected.sort, WorkflowDefinitionValidator::VALID_TYPES.sort
  end
end
