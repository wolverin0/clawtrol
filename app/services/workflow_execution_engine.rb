# frozen_string_literal: true

require "securerandom"

# Minimal workflow execution engine.
#
# - Validates DAG + required fields
# - Executes nodes in topological order
# - Returns per-node status + logs (no DB persistence yet)
class WorkflowExecutionEngine
  NodeResult = Struct.new(
    :id,
    :type,
    :label,
    :status,
    :started_at,
    :finished_at,
    :logs,
    :output,
    :session,
    keyword_init: true
  )

  RunResult = Struct.new(:run_id, :workflow_id, :status, :nodes, :errors, keyword_init: true) do
    def ok?
      errors.empty?
    end
  end

  def initialize(workflow, user:, logger: Rails.logger)
    @workflow = workflow
    @user = user
    @logger = logger
  end

  def run
    run_id = SecureRandom.uuid

    validation = WorkflowDefinitionValidator.validate(@workflow.definition)
    return RunResult.new(run_id: run_id, workflow_id: @workflow.id, status: "invalid", nodes: [], errors: validation.errors) unless validation.ok?

    nodes_by_id = validation.nodes.index_by { |n| n["id"] }

    results = []
    overall_status = "ok"

    validation.order.each do |node_id|
      node = nodes_by_id.fetch(node_id)
      results << execute_node(node, run_id: run_id)

      if results.last.status == "error"
        overall_status = "error"
        # Minimal engine: stop on first error.
        break
      end
    end

    RunResult.new(run_id: run_id, workflow_id: @workflow.id, status: overall_status, nodes: results, errors: [])
  rescue StandardError => e
    @logger.error("[WorkflowExecutionEngine] run failed workflow_id=#{@workflow.id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    RunResult.new(run_id: run_id, workflow_id: @workflow.id, status: "error", nodes: results || [], errors: ["execution failed: #{e.message}"])
  end

  private

  def execute_node(node, run_id:)
    started = Time.current
    logs = []

    type = node["type"]
    label = node["label"].presence || type

    case type
    when "trigger"
      logs << "trigger: start"
      status = "ok"
      output = { "message" => "started" }
      session = nil

    when "router"
      # Placeholder. Real behavior should evaluate conditions based on upstream outputs.
      logs << "router: TODO (conditional branching not implemented)"
      status = "skipped"
      output = { "todo" => "router node execution not implemented" }
      session = nil

    when "tool"
      # Placeholder for tool invocation.
      # In the future, this should call OpenClaw tool APIs.
      tool_name = node.dig("props", "tool") || node.dig("props", :tool)
      logs << "tool: #{tool_name.presence || "(unspecified)"}"
      logs << "tool: TODO (tool execution not implemented)"
      status = "skipped"
      output = { "todo" => "tool execution not implemented" }
      session = nil

    when "agent"
      model = (node.dig("props", "model") || node.dig("props", :model)).presence || "opus"
      prompt = (node.dig("props", "prompt") || node.dig("props", :prompt)).to_s

      if prompt.blank?
        logs << "agent: missing prompt; skipping (set node.props.prompt to enable)"
        status = "skipped"
        output = { "todo" => "set props.prompt to spawn an OpenClaw session", "model" => model }
        session = nil
      else
        logs << "agent: spawning OpenClaw session model=#{model}"

        client = OpenclawGatewayClient.new(@user, logger: @logger)
        spawn = client.spawn_session!(model: model, prompt: prompt)

        status = "ok"
        output = { "message" => "session spawned" }
        session = spawn
      end

    else
      logs << "unknown node type: #{type.inspect}"
      status = "error"
      output = { "error" => "unknown node type" }
      session = nil
    end

    finished = Time.current

    NodeResult.new(
      id: node["id"],
      type: type,
      label: label,
      status: status,
      started_at: started,
      finished_at: finished,
      logs: logs,
      output: output,
      session: session
    )
  rescue StandardError => e
    finished = Time.current
    NodeResult.new(
      id: node["id"],
      type: node["type"],
      label: node["label"],
      status: "error",
      started_at: started,
      finished_at: finished,
      logs: ["error: #{e.class}: #{e.message}"],
      output: { "error" => e.message },
      session: nil
    )
  end
end
