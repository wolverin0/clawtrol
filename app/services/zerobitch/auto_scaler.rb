# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"

module Zerobitch
  class AutoScaler
    RULES_PATH = Rails.root.join("storage", "zerobitch", "rules.json")

    class << self
      def rules
        read_rules
      end

      def add_rule(name:, condition:, action:, enabled: true)
        list = read_rules
        list << {
          id: "rule_#{SecureRandom.hex(4)}",
          name: name.to_s,
          condition: {
            type: condition[:type].to_s,
            threshold: condition[:threshold].to_i
          },
          action: {
            type: action[:type].to_s,
            template_id: action[:template_id].to_s.presence
          },
          enabled: enabled,
          last_triggered: nil
        }

        write_rules(list)
        list.last
      end

      def evaluate_rules
        list = read_rules
        triggered = 0
        errors = []

        list.each do |rule|
          next unless rule["enabled"]

          begin
            next unless condition_met?(rule["condition"] || {})

            execute_action(rule["action"] || {})
            rule["last_triggered"] = Time.current.iso8601
            triggered += 1
          rescue StandardError => e
            errors << { rule_id: rule["id"], error: e.message }
          end
        end

        write_rules(list)
        { triggered: triggered, errors: errors, rules: list }
      end

      private

      def read_rules
        return [] unless File.exist?(RULES_PATH)

        JSON.parse(File.read(RULES_PATH))
      rescue JSON::ParserError
        []
      end

      def write_rules(rules)
        FileUtils.mkdir_p(RULES_PATH.dirname)
        File.write(RULES_PATH, JSON.pretty_generate(rules))
      end

      def condition_met?(condition)
        threshold = condition["threshold"].to_f

        case condition["type"]
        when "idle_agents_below"
          running = DockerService.list_agents.count { |a| a[:state] == "running" }
          running < threshold
        when "idle_timeout"
          # True if any agent has no tasks in the last N minutes
          return false unless threshold.positive?
          cutoff = Time.current - (threshold * 60)
          AgentRegistry.all.any? do |agent|
            tasks = TaskHistory.all(agent[:id])
            tasks.empty? || Time.parse(tasks.last[:timestamp].to_s) < cutoff rescue true
          end
        when "queue_depth"
          # Check pending ClawTrol tasks (up_next count)
          token = ENV["CLAWTROL_API_TOKEN"]
          return false unless token
          uri = URI("http://localhost:4001/api/v1/tasks?status=up_next")
          req = Net::HTTP::Get.new(uri)
          req["Authorization"] = "Bearer #{token}"
          res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
          count = JSON.parse(res.body).is_a?(Array) ? JSON.parse(res.body).size : 0
          count > threshold
        when "error_rate"
          # Check recent task failure rate across all agents
          all_tasks = AgentRegistry.all.flat_map { |a| TaskHistory.all(a[:id]) }
          recent = all_tasks.select { |t| Time.parse(t[:timestamp].to_s) > 1.hour.ago rescue false }
          return false if recent.empty?
          fail_rate = (recent.count { |t| !t[:success] }.to_f / recent.size * 100)
          fail_rate > threshold
        else
          false
        end
      end

      def execute_action(action)
        case action["type"]
        when "spawn_from_template"
          template_id = action["template_id"].presence
          return false unless template_id
          # Log the intent — actual spawning requires the full create flow
          Rails.logger.info("[ZeroBitch AutoScaler] Would spawn from template: #{template_id}")
          true
        when "stop_idle"
          docker = DockerService.new
          AgentRegistry.all.each do |agent|
            tasks = TaskHistory.all(agent[:id])
            idle = tasks.empty? || (Time.parse(tasks.last[:timestamp].to_s) < 30.minutes.ago rescue true)
            docker.stop(agent[:container_name]) if idle rescue nil
          end
          true
        when "restart_unhealthy"
          docker = DockerService.new
          DockerService.list_agents.each do |da|
            next if da[:state] == "running"
            docker.start(da[:name]) rescue nil
          end
          true
        else
          raise ArgumentError, "Unknown action type: #{action['type']}"
        end
      end
    end
  end
end
