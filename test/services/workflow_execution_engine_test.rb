# frozen_string_literal: true

require "test_helper"

class WorkflowExecutionEngineTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def build_workflow(definition)
    Workflow.create!(
      user: @user,
      title: "Test Workflow #{SecureRandom.hex(4)}",
      definition: definition
    )
  end

  # --- Expression Evaluator ---

  test "evaluate_simple_expression: equality" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    assert engine.send(:evaluate_simple_expression, "foo == foo")
    assert_not engine.send(:evaluate_simple_expression, "foo == bar")
  end

  test "evaluate_simple_expression: inequality" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    assert engine.send(:evaluate_simple_expression, "foo != bar")
    assert_not engine.send(:evaluate_simple_expression, "foo != foo")
  end

  test "evaluate_simple_expression: numeric comparisons" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    assert engine.send(:evaluate_simple_expression, "10 > 5")
    assert_not engine.send(:evaluate_simple_expression, "5 > 10")
    assert engine.send(:evaluate_simple_expression, "10 >= 10")
    assert engine.send(:evaluate_simple_expression, "5 < 10")
    assert engine.send(:evaluate_simple_expression, "10 <= 10")
    assert_not engine.send(:evaluate_simple_expression, "10 < 5")
  end

  test "evaluate_simple_expression: contains" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    assert engine.send(:evaluate_simple_expression, "hello world contains hello")
    assert_not engine.send(:evaluate_simple_expression, "hello contains world")
  end

  test "evaluate_simple_expression: empty and not_empty" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    # empty(x) / not_empty(x) require at least one char inside parens
    assert_not engine.send(:evaluate_simple_expression, "empty(hello)")
    assert engine.send(:evaluate_simple_expression, "empty( )")
    assert engine.send(:evaluate_simple_expression, "not_empty(hello)")
  end

  test "evaluate_simple_expression: boolean literals" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    assert engine.send(:evaluate_simple_expression, "true")
    assert_not engine.send(:evaluate_simple_expression, "false")
    assert engine.send(:evaluate_simple_expression, "TRUE")
  end

  test "evaluate_simple_expression: blank returns true" do
    engine = WorkflowExecutionEngine.new(build_workflow({ "nodes" => [], "edges" => [] }), user: @user)
    assert engine.send(:evaluate_simple_expression, "")
    assert engine.send(:evaluate_simple_expression, nil)
  end

  # --- Workflow Execution ---

  test "run with invalid definition returns errors" do
    wf = Workflow.new(id: 999, user: @user, title: "Bad", definition: "not a hash")
    wf.save!(validate: false)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "invalid", result.status
    assert_not result.ok?
    assert result.errors.any?
  ensure
    wf.destroy
  end

  test "run with trigger-only workflow succeeds" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} }
      ],
      "edges" => []
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    assert result.ok?
    assert_equal 1, result.nodes.size
    assert_equal "ok", result.nodes.first.status
    assert_equal "trigger", result.nodes.first.type
  end

  test "run with router node evaluates expression" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "router", "label" => "Check", "props" => { "expression" => "true" } }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    assert_equal 2, result.nodes.size

    router = result.nodes.find { |n| n.type == "router" }
    assert_equal "ok", router.status
    assert_equal true, router.output["result"]
  end

  test "run with conditional node" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "conditional", "label" => "If", "props" => { "expression" => "1 > 0" } }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    cond = result.nodes.find { |n| n.type == "conditional" }
    assert_equal "ok", cond.status
    assert_equal true, cond.output["result"]
  end

  test "run with delay node zero duration is instant" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "delay", "label" => "Wait", "props" => { "duration" => "0" } }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    delay = result.nodes.find { |n| n.type == "delay" }
    assert_equal "ok", delay.status
    assert_equal 0, delay.output["duration_actual"]
  end

  test "run with unknown node type returns error and stops" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "unknown_type", "label" => "Bad", "props" => {} }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    # Bypass validation to test runtime error handling
    wf = Workflow.new(user: @user, title: "Bad type", definition: definition)
    wf.save!(validate: false)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    # Invalid type is caught by validator, returns "invalid"
    assert %w[invalid error].include?(result.status)
  ensure
    wf.destroy
  end

  test "run with tool node returns skipped" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "tool", "label" => "Tool", "props" => { "tool" => "web_search" } }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    tool = result.nodes.find { |n| n.type == "tool" }
    assert_equal "skipped", tool.status
  end

  test "run with agent node and no prompt returns skipped" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "agent", "label" => "Agent", "props" => {} }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    agent = result.nodes.find { |n| n.type == "agent" }
    assert_equal "skipped", agent.status
  end

  test "run with empty nodes is ok" do
    wf = build_workflow({ "nodes" => [], "edges" => [] })
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    assert result.ok?
    assert_empty result.nodes
  end

  test "router with variable interpolation from upstream" do
    definition = {
      "nodes" => [
        { "id" => "n1", "type" => "trigger", "label" => "Start", "props" => {} },
        { "id" => "n2", "type" => "router", "label" => "Check", "props" => { "expression" => "{{n1.message}} == started" } }
      ],
      "edges" => [{ "from" => "n1", "to" => "n2" }]
    }
    wf = build_workflow(definition)
    engine = WorkflowExecutionEngine.new(wf, user: @user)
    result = engine.run

    assert_equal "ok", result.status
    router = result.nodes.find { |n| n.type == "router" }
    assert_equal true, router.output["result"]
  end
end
