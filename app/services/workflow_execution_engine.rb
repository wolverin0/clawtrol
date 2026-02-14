# frozen_string_literal: true

require "securerandom"

# Workflow execution engine with support for 8 node types.
#
# - Validates DAG + required fields
# - Executes nodes in topological order
# - Returns per-node status + logs (no DB persistence yet)
class WorkflowExecutionEngine
  NodeResult = Struct.new(
    :id, :type, :label, :status, :started_at, :finished_at,
    :logs, :output, :session,
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
    @node_outputs = {} # id -> output hash, for passing data between nodes
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
      result = execute_node(node, run_id: run_id)
      results << result
      @node_outputs[node_id] = result.output

      if result.status == "error"
        overall_status = "error"
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
      logs << "trigger: workflow started"
      status = "ok"
      output = { "message" => "started", "run_id" => run_id }
      session = nil

    when "agent"
      model = prop(node, "model").presence || "opus"
      prompt = prop(node, "prompt").to_s

      if prompt.blank?
        logs << "agent: missing prompt; skipping"
        status = "skipped"
        output = { "todo" => "set props.prompt to spawn session", "model" => model }
        session = nil
      else
        logs << "agent: spawning session model=#{model}"
        client = OpenclawGatewayClient.new(@user, logger: @logger)
        spawn = client.spawn_session!(model: model, prompt: prompt)
        status = "ok"
        output = { "message" => "session spawned", "model" => model }
        session = spawn
      end

    when "tool"
      tool_name = prop(node, "tool")
      logs << "tool: #{tool_name.presence || "(unspecified)"} — execution not yet implemented"
      status = "skipped"
      output = { "todo" => "tool execution pending implementation" }
      session = nil

    when "router"
      expression = prop(node, "expression").to_s.strip
      logs << "router: evaluating '#{expression}'"

      if expression.blank?
        logs << "router: no expression, defaulting to true"
        status = "ok"
        output = { "result" => true, "path" => "default" }
      else
        # Simple expression evaluator: supports comparisons and logical operators
        # Replaces {{node_id.field}} with actual values from previous node outputs
        resolved = expression.gsub(/\{\{(\w+)\.(\w+)\}\}/) do |match|
          node_id = $1
          field = $2
          prev_output = @node_outputs[node_id]
          prev_output.is_a?(Hash) ? prev_output[field].to_s : ""
        end

        result = evaluate_simple_expression(resolved)
        logs << "router: resolved='#{resolved}' result=#{result}"
        status = "ok"
        output = { "expression" => expression, "resolved" => resolved, "result" => result, "path" => result ? "true" : "false" }
      end
      session = nil

    when "nightshift"
      mission_name = prop(node, "mission_name")
      mission_id = prop(node, "mission_id")
      model = prop(node, "model")

      if mission_name.blank? && mission_id.blank?
        logs << "nightshift: missing mission_name or mission_id; skipping"
        status = "skipped"
        output = { "todo" => "set props.mission_name or props.mission_id" }
        session = nil
      else
        mission = if mission_id.present?
                    NightshiftMission.find_by(id: mission_id)
                  else
                    NightshiftMission.find_by(name: mission_name)
                  end

        if mission.nil?
          logs << "nightshift: mission not found (name=#{mission_name}, id=#{mission_id})"
          status = "error"
          output = { "error" => "mission not found" }
          session = nil
        else
          logs << "nightshift: launching mission '#{mission.name}' (id=#{mission.id})"

          # Create or find tonight's selection
          selection = NightshiftSelection.find_or_create_by!(
            nightshift_mission_id: mission.id,
            scheduled_date: Date.current
          ) do |sel|
            sel.title = mission.name
            sel.enabled = true
            sel.status = "pending"
          end

          # Mark as running and wake OpenClaw
          selection.update!(status: "running", launched_at: Time.current) if selection.status == "pending"

          logs << "nightshift: selection ##{selection.id} marked running"
          status = "ok"
          output = { "mission_id" => mission.id, "selection_id" => selection.id, "mission_name" => mission.name }
          session = nil
        end
      end

    when "conditional", "if"
      expression = prop(node, "expression").to_s.strip
      logs << "conditional: evaluating '#{expression}'"

      resolved = expression.gsub(/\{\{(\w+)\.(\w+)\}\}/) do
        node_id = $1; field = $2
        prev = @node_outputs[node_id]
        prev.is_a?(Hash) ? prev[field].to_s : ""
      end

      result = evaluate_simple_expression(resolved)
      logs << "conditional: #{result ? 'TRUE path' : 'FALSE path'}"
      status = "ok"
      output = { "expression" => expression, "result" => result }
      session = nil

    when "notification"
      channel = prop(node, "channel") || "telegram"
      message = prop(node, "message") || "Workflow notification"

      logs << "notification: channel=#{channel}"

      # Simple variable interpolation from upstream node outputs
      interpolated = message.gsub(/\{\{(\w+)\}\}/) do
        key = $1
        @node_outputs.values.last&.dig(key) || key
      end

      case channel
      when "telegram"
        # Use OpenClaw gateway to send Telegram notification
        begin
          client = OpenclawGatewayClient.new(@user, logger: @logger)
          client.send_message(interpolated)
          logs << "notification: sent via OpenClaw gateway"
          status = "ok"
        rescue => e
          logs << "notification: failed to send — #{e.message}"
          status = "error"
        end
      when "webhook"
        logs << "notification: webhook delivery not yet implemented"
        status = "skipped"
      else
        logs << "notification: unknown channel #{channel}"
        status = "skipped"
      end

      output = { "channel" => channel, "message" => interpolated }
      session = nil

    when "delay"
      duration = (prop(node, "duration") || "0").to_i.clamp(0, 300)
      logs << "delay: #{duration}s requested"
      if duration > 10
        logs << "delay: capped to 10s in synchronous mode (use async workflows for longer delays)"
        sleep(10)
      elsif duration > 0
        sleep(duration)
      end
      logs << "delay: completed"
      status = "ok"
      output = { "duration_requested" => duration, "duration_actual" => [duration, 10].min }
      session = nil

    else
      logs << "unknown node type: #{type.inspect}"
      status = "error"
      output = { "error" => "unknown node type" }
      session = nil
    end

    NodeResult.new(
      id: node["id"], type: type, label: label, status: status,
      started_at: started, finished_at: Time.current,
      logs: logs, output: output, session: session
    )
  rescue StandardError => e
    NodeResult.new(
      id: node["id"], type: node["type"], label: node["label"], status: "error",
      started_at: started, finished_at: Time.current,
      logs: ["error: #{e.class}: #{e.message}"], output: { "error" => e.message }, session: nil
    )
  end


  def evaluate_simple_expression(expr)
    return true if expr.blank?

    # Simple expression evaluator for safe expressions
    # Supports: ==, !=, >, <, >=, <=, contains, empty, not_empty
    case expr.strip
    when /\A(.+?)\s*==\s*(.+)\z/
      $1.strip == $2.strip
    when /\A(.+?)\s*!=\s*(.+)\z/
      $1.strip != $2.strip
    when /\A(.+?)\s*>=\s*(.+)\z/
      $1.strip.to_f >= $2.strip.to_f
    when /\A(.+?)\s*<=\s*(.+)\z/
      $1.strip.to_f <= $2.strip.to_f
    when /\A(.+?)\s*>\s*(.+)\z/
      $1.strip.to_f > $2.strip.to_f
    when /\A(.+?)\s*<\s*(.+)\z/
      $1.strip.to_f < $2.strip.to_f
    when /\A(.+?)\s+contains\s+(.+)\z/i
      $1.strip.downcase.include?($2.strip.downcase)
    when /\Aempty\((.+?)\)\z/i
      $1.strip.empty?
    when /\Anot_empty\((.+?)\)\z/i
      !$1.strip.empty?
    when /\Atrue\z/i
      true
    when /\Afalse\z/i
      false
    else
      # Default: treat non-empty strings as truthy
      expr.strip.present?
    end
  rescue => e
    Rails.logger.warn("[WorkflowEngine] expression eval failed: #{e.message}")
    false
  end

  def prop(node, key)
    node.dig("props", key) || node.dig("props", key.to_sym)
  end
end
