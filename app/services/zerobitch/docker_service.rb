# frozen_string_literal: true

require "json"
require "open3"
require "timeout"

module Zerobitch
  class DockerService
    CONTAINER_PREFIX = "zeroclaw-"
    IMAGE_NAME = "zeroclaw-fleet:latest"

    class << self
      def list_agents
        stdout, _stderr, status = capture_docker("ps", "-a", "--filter", "name=#{CONTAINER_PREFIX}", "--format", "{{json .}}")
        return [] unless status.success?

        stdout.lines.filter_map do |line|
          row = JSON.parse(line)
          name = row["Names"].to_s
          next unless name.start_with?(CONTAINER_PREFIX)

          {
            name: name,
            state: row["State"],
            status: row["Status"],
            ports: row["Ports"],
            created: row["RunningFor"],
            image: row["Image"]
          }
        rescue JSON::ParserError
          nil
        end
      end

      def container_stats(name)
        container = container_name(name)
        stdout, _stderr, status = capture_docker("stats", "--no-stream", "--format", "{{json .}}", container)
        return {} unless status.success?

        row = JSON.parse(stdout.lines.first || "{}")
        mem_usage_raw = row["MemUsage"].to_s
        mem_usage, mem_limit = parse_mem_usage(mem_usage_raw, row["MemLimit"])
        {
          mem_usage: mem_usage,
          cpu_percent: row["CPUPerc"],
          mem_limit: mem_limit,
          mem_percent: row["MemPerc"]
        }
      rescue JSON::ParserError
        {}
      end

      def container_state(name)
        container = container_name(name)
        stdout, _stderr, status = capture_docker("inspect", container)
        return {} unless status.success?

        row = JSON.parse(stdout).first || {}
        state = row["State"] || {}
        {
          status: state["Status"],
          restart_count: state["RestartCount"],
          started_at: state["StartedAt"],
          finished_at: state["FinishedAt"]
        }
      rescue JSON::ParserError
        {}
      end

      def start(name)
        run_simple("start", container_name(name))
      end

      def stop(name)
        run_simple("stop", container_name(name))
      end

      def restart(name)
        run_simple("restart", container_name(name))
      end

      def remove(name)
        container = container_name(name)
        _stdout, _stderr, stop_status = capture_docker("stop", container)
        rm_stdout, rm_stderr, rm_status = capture_docker("rm", container)

        {
          success: stop_status.success? && rm_status.success?,
          output: rm_stdout,
          error: rm_stderr,
          exit_code: rm_status.exitstatus
        }
      end

      def logs(name, tail: 100)
        stdout, stderr, status = capture_docker("logs", "--tail", tail.to_i.to_s, container_name(name))
        {
          success: status.success?,
          output: stdout,
          error: stderr,
          exit_code: status.exitstatus
        }
      end

      def cron_list(name, json: true)
        container = container_name(name)
        args = ["exec", container, "zeroclaw", "cron", "list"]
        args << "--json" if json
        stdout, stderr, status = capture_docker(*args, timeout_seconds: 15)
        {
          success: status.success?,
          output: stdout,
          error: stderr,
          exit_code: status.exitstatus
        }
      end

      def run(name:, config_path:, workspace_path:, port:, mem_limit: "32m", cpu_limit: "0.5", command: "daemon")
        container = container_name(name)

        args = [
          "run", "-d",
          "--name", container,
          "--restart", "unless-stopped",
          "-v", "#{config_path}:/home/zclaw/.zeroclaw/config.toml:ro",
          "-v", "#{workspace_path}:/home/zclaw/.zeroclaw/workspace",
          "-p", "#{port}:8080",
          "--memory", mem_limit.to_s,
          "--cpus", cpu_limit.to_s,
          IMAGE_NAME,
          command.to_s
        ]

        stdout, stderr, status = capture_docker(*args, timeout_seconds: 90)
        {
          success: status.success?,
          output: stdout,
          error: stderr,
          exit_code: status.exitstatus
        }
      end

      def exec_task(name, prompt, timeout: 60)
        container = container_name(name)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        stdout, stderr, status = capture(
          [
            "timeout", "#{timeout.to_i}s",
            "docker", "exec", container,
            "zeroclaw", "agent", "-m", prompt.to_s
          ],
          timeout_seconds: timeout.to_i + 5
        )

        finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        {
          output: [stdout, stderr].reject(&:empty?).join,
          exit_code: status.exitstatus,
          duration_ms: ((finished_at - started_at) * 1000).round
        }
      end

      private

      def run_simple(*args)
        stdout, stderr, status = capture_docker(*args)
        {
          success: status.success?,
          output: stdout,
          error: stderr,
          exit_code: status.exitstatus
        }
      end

      def container_name(name)
        candidate = name.to_s.strip
        return candidate if candidate.start_with?(CONTAINER_PREFIX)

        safe = sanitize_name(candidate)
        "#{CONTAINER_PREFIX}#{safe}"
      end

      def sanitize_name(name)
        candidate = name.to_s.strip.downcase
        raise ArgumentError, "Container name cannot be blank" if candidate.blank?

        safe = candidate.gsub(/[^a-z0-9-]/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
        raise ArgumentError, "Invalid container name" if safe.blank?

        safe
      end

      def capture_docker(*args, timeout_seconds: 30)
        capture(["docker", *args], timeout_seconds: timeout_seconds)
      end

      def capture(command_array, timeout_seconds: 30)
        Timeout.timeout(timeout_seconds) do
          Open3.capture3(*command_array)
        end
      rescue Timeout::Error
        ["", "Command timed out after #{timeout_seconds}s", timeout_status]
      end

      def parse_mem_usage(mem_usage_raw, mem_limit_raw)
        usage = mem_usage_raw.to_s
        limit = mem_limit_raw
        if usage.include?("/")
          parts = usage.split("/", 2).map(&:strip)
          usage = parts[0]
          limit = parts[1] if parts[1].present?
        end
        [usage.presence || mem_usage_raw, limit.presence]
      end

      def timeout_status
        @timeout_status ||= Struct.new(:success?, :exitstatus).new(false, 124)
      end
    end
  end
end
