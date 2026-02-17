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
    # Clear gateway env vars so the CLI connects as an external client,
    # not as an internal gateway subprocess (which causes WS auth issues).
    clean_env = {
      "OPENCLAW_SERVICE_KIND" => nil,
      "OPENCLAW_SYSTEMD_UNIT" => nil
    }

    stdout, stderr, status = ::Timeout.timeout(openclaw_timeout_seconds) do
      Open3.capture3(clean_env, "openclaw", *args.map(&:to_s))
    end

    { stdout: stdout, stderr: stderr, exitstatus: status&.exitstatus }
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
