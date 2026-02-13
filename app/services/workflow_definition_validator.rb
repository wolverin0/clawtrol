# frozen_string_literal: true

require "set"

# Validates and normalizes the Workflow.definition JSON (nodes + edges)
# and provides a topological order for execution.
#
# Definition format (from workflow_editor_controller.js):
# { nodes: [{id,type,label,x,y,props}], edges: [{from,to}] }
class WorkflowDefinitionValidator
  Result = Struct.new(:nodes, :edges, :order, :errors, keyword_init: true) do
    def ok?
      errors.empty?
    end
  end

  VALID_TYPES = %w[trigger agent tool router nightshift conditional notification delay].freeze

  def self.validate(definition)
    new(definition).validate
  end

  def initialize(definition)
    @definition = definition
  end

  def validate
    errors = []

    unless @definition.is_a?(Hash)
      return Result.new(nodes: [], edges: [], order: [], errors: ["definition must be a JSON object"])
    end

    nodes = Array(@definition["nodes"] || @definition[:nodes])
    edges = Array(@definition["edges"] || @definition[:edges])

    unless nodes.all? { |n| n.is_a?(Hash) }
      errors << "nodes must be an array of objects"
      nodes = []
    end

    unless edges.all? { |e| e.is_a?(Hash) }
      errors << "edges must be an array of objects"
      edges = []
    end

    normalized_nodes = nodes.map do |n|
      {
        "id" => (n["id"] || n[:id]).to_s,
        "type" => (n["type"] || n[:type]).to_s.downcase,
        "label" => (n["label"] || n[:label]).to_s,
        "props" => (n["props"] || n[:props] || {})
      }
    end

    # Node validations
    ids = normalized_nodes.map { |n| n["id"] }
    if ids.any?(&:blank?)
      errors << "all nodes must have an id"
    end

    if ids.uniq.length != ids.length
      errors << "node ids must be unique"
    end

    normalized_nodes.each do |n|
      if n["type"].blank?
        errors << "node #{n["id"].presence || "(missing id)"} must have a type"
        next
      end

      unless VALID_TYPES.include?(n["type"])
        errors << "node #{n["id"]} has invalid type #{n["type"]}"
      end

      unless n["props"].is_a?(Hash)
        errors << "node #{n["id"]} props must be an object"
        n["props"] = {}
      end
    end

    normalized_edges = edges.map do |e|
      {
        "from" => (e["from"] || e[:from]).to_s,
        "to" => (e["to"] || e[:to]).to_s
      }
    end

    normalized_edges.each do |e|
      errors << "edge missing from" if e["from"].blank?
      errors << "edge missing to" if e["to"].blank?
    end

    node_id_set = ids.to_set
    normalized_edges.each do |e|
      next if e["from"].blank? || e["to"].blank?

      errors << "edge from #{e["from"]} references missing node" unless node_id_set.include?(e["from"])
      errors << "edge to #{e["to"]} references missing node" unless node_id_set.include?(e["to"])
    end

    order = []
    if errors.empty?
      order = topo_sort(ids, normalized_edges)
      if order.nil?
        errors << "workflow has a cycle (not a DAG)"
        order = []
      end
    end

    Result.new(nodes: normalized_nodes, edges: normalized_edges, order: order, errors: errors)
  end

  private

  # Kahn's algorithm. Returns array of node ids, or nil if cycle.
  def topo_sort(node_ids, edges)
    outgoing = Hash.new { |h, k| h[k] = [] }
    indegree = Hash.new(0)

    node_ids.each { |id| indegree[id] = 0 }

    edges.each do |e|
      from = e["from"]
      to = e["to"]
      outgoing[from] << to
      indegree[to] += 1
    end

    queue = node_ids.select { |id| indegree[id].zero? }.sort
    order = []

    until queue.empty?
      id = queue.shift
      order << id
      outgoing[id].each do |to|
        indegree[to] -= 1
        queue << to if indegree[to].zero?
      end
      queue.sort!
    end

    return nil if order.length != node_ids.length

    order
  end
end
