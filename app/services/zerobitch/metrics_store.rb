# frozen_string_literal: true

require "json"
require "fileutils"

module Zerobitch
  class MetricsStore
    MAX_POINTS = 120 # 120 x 30s = 1 hour of history
    STORE_PATH = Rails.root.join("storage", "zerobitch", "metrics.json")

    class << self
      def record(agent_id, mem_mb:, cpu_percent:)
        data = load
        data[agent_id] ||= []
        data[agent_id] << {
          t: Time.current.to_i,
          mem: mem_mb.round(2),
          cpu: cpu_percent.round(2)
        }
        data[agent_id] = data[agent_id].last(MAX_POINTS)
        save(data)
      end

      def history(agent_id, points: 60)
        data = load
        (data[agent_id] || []).last(points)
      end

      def all_histories(points: 60)
        data = load
        data.transform_values { |v| v.last(points) }
      end

      def collect_all
        docker = DockerService
        AgentRegistry.all.each do |agent|
          stats = docker.container_stats(agent[:container_name]) rescue next
          next if stats.empty?

          mem_mb = parse_mem_mb(stats[:mem_usage])
          cpu = parse_percent(stats[:cpu_percent])
          record(agent[:id], mem_mb: mem_mb, cpu_percent: cpu)
        end
      end

      def tasks_today
        today = Time.current.beginning_of_day.utc.iso8601
        dir = Rails.root.join("storage", "zerobitch", "tasks")
        return 0 unless dir.exist?

        Dir.glob(dir.join("*.json")).sum do |f|
          entries = JSON.parse(File.read(f), symbolize_names: true) rescue []
          entries.count { |e| e[:timestamp].to_s >= today }
        end
      end

      private

      def parse_mem_mb(str)
        return 0.0 unless str
        val, unit = str.strip.split(/\s*\/\s*/).first&.match(/([\d.]+)\s*(\w+)/)&.captures || [0, "MiB"]
        case unit&.downcase
        when "gib" then val.to_f * 1024
        when "kib" then val.to_f / 1024
        else val.to_f
        end
      end

      def parse_percent(str)
        str.to_s.gsub("%", "").to_f
      end

      def load
        return {} unless File.exist?(STORE_PATH)
        JSON.parse(File.read(STORE_PATH))
      rescue JSON::ParserError
        {}
      end

      def save(data)
        FileUtils.mkdir_p(STORE_PATH.dirname)
        File.write(STORE_PATH, JSON.generate(data))
      end
    end
  end
end
