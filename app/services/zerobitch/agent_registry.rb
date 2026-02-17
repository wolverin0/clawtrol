# frozen_string_literal: true

require "json"
require "fileutils"
require "time"
require "set"

module Zerobitch
  class AgentRegistry
    REGISTRY_PATH = Rails.root.join("storage", "zerobitch", "agents.json")
    PORT_RANGE = (18_081..18_199)
    REQUIRED_ATTRS = %i[name emoji role provider model mode].freeze

    def self.all
      read_registry
    end

    def self.find(id)
      read_registry.find { |agent| agent[:id] == id.to_s }
    end

    def self.create(attrs)
      attrs = attrs.to_h.symbolize_keys
      validate_required!(attrs)

      agents = read_registry
      id = unique_id_for(attrs[:name], agents)
      port = attrs[:port].presence || next_available_port(agents)

      agent = {
        id: id,
        name: attrs[:name],
        emoji: attrs[:emoji],
        role: attrs[:role],
        container_name: attrs[:container_name].presence || "zeroclaw-#{id}",
        port: port,
        provider: attrs[:provider],
        model: attrs[:model],
        api_key_name: attrs[:api_key_name],
        mode: attrs[:mode],
        autonomy: attrs[:autonomy].presence || "supervised",
        mem_limit: attrs[:mem_limit].presence || "32m",
        cpu_limit: attrs[:cpu_limit].presence || 0.5,
        allowed_commands: Array(attrs[:allowed_commands]),
        created_at: Time.current.utc.iso8601,
        template: attrs[:template]
      }

      agents << agent
      write_registry(agents)
      agent
    end

    def self.update(id, attrs)
      attrs = attrs.to_h.symbolize_keys
      agents = read_registry
      index = agents.index { |agent| agent[:id] == id.to_s }
      return nil unless index

      updated = agents[index].merge(attrs.except(:id, :created_at))
      updated[:id] = agents[index][:id]
      updated[:created_at] = agents[index][:created_at]

      agents[index] = updated
      write_registry(agents)
      updated
    end

    def self.destroy(id)
      agents = read_registry
      before_count = agents.length
      agents.reject! { |agent| agent[:id] == id.to_s }
      return false if agents.length == before_count

      write_registry(agents)
      true
    end

    def self.next_available_port(agents = read_registry)
      used_ports = agents.map { |agent| agent[:port].to_i }.to_set
      port = PORT_RANGE.find { |candidate| !used_ports.include?(candidate) }
      raise "No available ports in range #{PORT_RANGE.begin}-#{PORT_RANGE.end}" unless port

      port
    end

    private

    def self.validate_required!(attrs)
      missing = REQUIRED_ATTRS.select { |key| attrs[key].blank? }
      return if missing.empty?

      raise ArgumentError, "Missing required attrs: #{missing.join(', ')}"
    end

    def self.unique_id_for(name, agents)
      base = name.to_s.downcase.strip.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "")
      base = "agent" if base.blank?

      existing_ids = agents.map { |agent| agent[:id] }
      return base unless existing_ids.include?(base)

      suffix = 2
      loop do
        candidate = "#{base}-#{suffix}"
        return candidate unless existing_ids.include?(candidate)

        suffix += 1
      end
    end

    def self.read_registry
      return [] unless File.exist?(REGISTRY_PATH)

      JSON.parse(File.read(REGISTRY_PATH), symbolize_names: true)
    rescue JSON::ParserError
      []
    end

    def self.write_registry(agents)
      FileUtils.mkdir_p(File.dirname(REGISTRY_PATH))
      File.write(REGISTRY_PATH, JSON.pretty_generate(agents))
    end
  end
end
