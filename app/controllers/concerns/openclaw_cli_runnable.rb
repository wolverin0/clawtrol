# frozen_string_literal: true

require "open3"
require "timeout"

# Provides shared helpers for controllers that run the `openclaw` CLI.
#
# Extracts the common pattern of:
#   - Running CLI commands with timeout + error handling
#   - Parsing JSON output
#   - Converting millisecond timestamps
#   - Configurable timeout via ENV
#
# Usage:
#   class SomeController < ApplicationController
#     include OpenclawCliRunnable
#
#     def index
#       result = run_openclaw_cli("sessions", "--active", "120", "--json")
#       # result => { stdout:, stderr:, exitstatus: }
#     end
#   end
module OpenclawCliRunnable
  extend ActiveSupport::Concern

  private

  # Run an openclaw CLI command with timeout and structured result.
  #
  # @param args [Array<String>] CLI arguments (e.g. "sessions", "--active", "120", "--json")
  # @return [Hash] { stdout:, stderr:, exitstatus: }
  def run_openclaw_cli(*args)
    # Load ~/.openclaw/.env so CLI config substitutions (e.g. CLAWTROL_API_TOKEN)
    # are available even when Puma/systemd wasn't started with that env file.
    # Also clear gateway-internal markers to force external-client behavior.
    cli_env = openclaw_cli_env_from_file.merge(
      "OPENCLAW_SERVICE_KIND" => nil,
      "OPENCLAW_SYSTEMD_UNIT" => nil
    )

    stdout, stderr, status = ::Timeout.timeout(openclaw_timeout_seconds) do
      Open3.capture3(cli_env, "openclaw", *args.map(&:to_s))
    end

    { stdout: stdout, stderr: stderr, exitstatus: status&.exitstatus }
  rescue Errno::ENOENT
    { stdout: "", stderr: "openclaw CLI not found", exitstatus: 127 }
  rescue ::Timeout::Error
    { stdout: "", stderr: "Command timed out", exitstatus: 124 }
  end

  # Run an openclaw CLI command and parse JSON output.
  # Returns parsed Hash on success, or an error Hash on failure.
  #
  # @param args [Array<String>] CLI arguments
  # @param label [String] human-readable label for error messages (e.g. "sessions", "cron list")
  # @return [Hash] parsed JSON or { status: "offline", error: "..." }
  def run_openclaw_cli_json(*args, label: "openclaw")
    result = run_openclaw_cli(*args)

    unless result[:exitstatus] == 0
      msg = "#{label} failed"
      msg += " (exit=#{result[:exitstatus]})" if result[:exitstatus]
      msg += ": #{result[:stderr].strip}" if result[:stderr].present?
      return { status: "offline", error: msg }
    end

    JSON.parse(result[:stdout])
  rescue Errno::ENOENT
    { status: "offline", error: "openclaw CLI not found" }
  rescue ::Timeout::Error
    { status: "offline", error: "#{label} timed out" }
  rescue JSON::ParserError
    { status: "offline", error: "invalid JSON from #{label}" }
  end

  # Convert millisecond timestamp to Time object.
  #
  # @param ms [Integer, String, nil] milliseconds since epoch
  # @return [Time, nil]
  def ms_to_time(ms)
    return nil if ms.blank?
    Time.at(ms.to_f / 1000.0)
  rescue StandardError
    nil
  end

  # Parse ~/.openclaw/.env into a Hash for child-process execution.
  # Supports plain KEY=value and `export KEY=value` lines.
  def openclaw_cli_env_from_file
    return @openclaw_cli_env_from_file if defined?(@openclaw_cli_env_from_file)

    env = {}
    env_path = File.expand_path("~/.openclaw/.env")

    if File.file?(env_path)
      File.foreach(env_path) do |line|
        line = line.to_s.strip
        next if line.blank? || line.start_with?("#")

        line = line.sub(/\Aexport\s+/, "")
        key, raw_value = line.split("=", 2)
        next if key.blank? || raw_value.nil?

        value = raw_value.strip
        if (value.start_with?("\"") && value.end_with?("\"")) ||
           (value.start_with?("'") && value.end_with?("'"))
          value = value[1..-2]
        end

        env[key] = value
      end
    end

    @openclaw_cli_env_from_file = env
  rescue StandardError => e
    Rails.logger.warn("[OpenclawCliRunnable] Failed to parse ~/.openclaw/.env: #{e.class}: #{e.message}")
    @openclaw_cli_env_from_file = {}
  end

  # Configurable timeout for CLI commands (seconds).
  # Override via ENV OPENCLAW_COMMAND_TIMEOUT_SECONDS.
  #
  # @return [Integer]
  def openclaw_timeout_seconds
    Integer(ENV.fetch("OPENCLAW_COMMAND_TIMEOUT_SECONDS", "20"))
  rescue ArgumentError
    20
  end
end
