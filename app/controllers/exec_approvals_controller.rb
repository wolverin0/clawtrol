# frozen_string_literal: true

# Manage OpenClaw per-node command allowlists (exec-approvals.json).
#
# OpenClaw stores exec approval lists per node at ~/.openclaw/exec-approvals.json.
# This controller reads the file via the gateway config and provides a UI to
# view, add, and remove approved commands per node.
class ExecApprovalsController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  APPROVALS_FILE = "exec-approvals.json"

  # GET /exec_approvals
  def index
    @config_data = gateway_client.config_get
    @nodes_data = gateway_client.nodes_status
    @approvals = extract_approvals(@config_data)
    @node_list = extract_nodes(@nodes_data)
    @recent_exec_logs = extract_exec_history(@config_data)
  end

  # POST /exec_approvals/add
  def add
    node_id = params[:node_id].to_s.strip
    command = params[:command].to_s.strip

    if node_id.blank? || command.blank?
      render json: { success: false, error: "Node ID and command are required" }, status: :unprocessable_entity
      return
    end

    # Sanitize inputs
    unless node_id.match?(/\A[a-zA-Z0-9._:-]{1,128}\z/)
      render json: { success: false, error: "Invalid node ID format" }, status: :unprocessable_entity
      return
    end

    if command.length > 1000
      render json: { success: false, error: "Command too long (max 1000 chars)" }, status: :unprocessable_entity
      return
    end

    # Read current approvals, add the command
    config = gateway_client.config_get
    current = extract_approvals_raw(config)
    current[node_id] ||= []
    unless current[node_id].include?(command)
      current[node_id] << command
    end

    save_approvals(current)
  end

  # DELETE /exec_approvals/remove
  def remove
    node_id = params[:node_id].to_s.strip
    command = params[:command].to_s.strip

    if node_id.blank? || command.blank?
      render json: { success: false, error: "Node ID and command are required" }, status: :unprocessable_entity
      return
    end

    config = gateway_client.config_get
    current = extract_approvals_raw(config)
    if current[node_id].is_a?(Array)
      current[node_id].delete(command)
      current.delete(node_id) if current[node_id].empty?
    end

    save_approvals(current)
  end

  # POST /exec_approvals/bulk_import
  def bulk_import
    node_id = params[:node_id].to_s.strip
    commands_text = params[:commands].to_s.strip

    if node_id.blank? || commands_text.blank?
      render json: { success: false, error: "Node ID and commands are required" }, status: :unprocessable_entity
      return
    end

    unless node_id.match?(/\A[a-zA-Z0-9._:-]{1,128}\z/)
      render json: { success: false, error: "Invalid node ID format" }, status: :unprocessable_entity
      return
    end

    commands = commands_text.split("\n").map(&:strip).reject(&:blank?).first(200)

    config = gateway_client.config_get
    current = extract_approvals_raw(config)
    current[node_id] ||= []
    commands.each do |cmd|
      current[node_id] << cmd unless current[node_id].include?(cmd)
    end

    save_approvals(current)
  end

  private

  def extract_approvals(config)
    raw = extract_approvals_raw(config)
    raw.map do |node_id, commands|
      {
        node_id: node_id,
        commands: Array(commands),
        count: Array(commands).size
      }
    end
  end

  def extract_approvals_raw(config)
    return {} unless config.is_a?(Hash) && config["error"].blank?

    raw_config = config.dig("config") || config
    raw_config.dig("exec", "approvals") ||
      raw_config["execApprovals"] ||
      {}
  end

  def extract_nodes(nodes_data)
    return [] unless nodes_data.is_a?(Hash)

    nodes = nodes_data["nodes"] || []
    Array(nodes).map do |n|
      {
        id: n["id"] || n["name"],
        name: n["name"] || n["id"],
        platform: n["platform"],
        online: n["online"] || n["connected"]
      }
    end
  end

  def extract_exec_history(config)
    # Exec history may be available from health or audit logs
    # For now, return empty — can be enhanced with webhook logs
    []
  end

  def save_approvals(approvals_hash)
    patch = { "exec" => { "approvals" => approvals_hash } }
    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Exec approvals updated from ClawTrol"
    )

    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Exec approvals saved. Gateway restarting..." }
    end
  end
end
