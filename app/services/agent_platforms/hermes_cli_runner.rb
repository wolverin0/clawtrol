# frozen_string_literal: true

require "open3"
require "timeout"

module AgentPlatforms
  # Safe wrapper around the local `hermes` CLI.
  #
  # Design goals:
  #   - Never crash a request because Hermes is missing or hung; return a
  #     structured result instead.
  #   - Never log token contents.
  #   - Respect per-user HERMES_HOME / profile, but never read the user's
  #     home .env unless explicitly requested.
  #
  # Returns { stdout:, stderr:, exitstatus:, status: :ok | :offline | :unsupported }.
  class HermesCliRunner
    DEFAULT_TIMEOUT_SECONDS = 20

    attr_reader :user

    def initialize(user, logger: Rails.logger)
      @user = user
      @logger = logger
    end

    # Run a hermes CLI command and return structured stdout/stderr.
    # Returns an offline result if the binary is missing or the call times out.
    def run(*args, timeout: nil)
      cmd = cli_path
      env = build_env

      effective_args = profile_args + args.map(&:to_s)

      stdout, stderr, status = ::Timeout.timeout(timeout || timeout_seconds) do
        Open3.capture3(env, cmd, *effective_args)
      end

      {
        stdout: stdout.to_s,
        stderr: stderr.to_s,
        exitstatus: status&.exitstatus,
        status: status&.success? ? :ok : :error
      }
    rescue Errno::ENOENT
      { stdout: "", stderr: "hermes CLI not found", exitstatus: 127, status: :offline }
    rescue ::Timeout::Error
      { stdout: "", stderr: "hermes command timed out", exitstatus: 124, status: :offline }
    rescue StandardError => e
      { stdout: "", stderr: e.message, exitstatus: nil, status: :offline }
    end

    # Run a hermes CLI command expecting JSON on stdout. Returns parsed JSON
    # on success, or { status: "offline"|"unsupported", error: "..." }
    # on any failure.
    def run_json(*args, label: "hermes", timeout: nil)
      result = run(*args, timeout: timeout)

      case result[:status]
      when :offline
        { "status" => "offline", "error" => result[:stderr].to_s.strip.presence || "#{label} offline" }
      when :error
        { "status" => "error",
          "error" => "#{label} failed (exit=#{result[:exitstatus]}): #{result[:stderr].to_s.strip}".strip }
      else
        begin
          JSON.parse(result[:stdout])
        rescue JSON::ParserError
          { "status" => "unsupported", "error" => "invalid JSON from #{label}" }
        end
      end
    end

    private

    def cli_path
      ENV["HERMES_CLI_PATH"].presence || "hermes"
    end

    def build_env
      env = {}
      home = expanded_hermes_home
      env["HERMES_HOME"] = home if home.present?
      env
    end

    def profile_args
      profile = user.try(:hermes_profile).to_s.strip
      profile.empty? ? [] : ["--profile", profile]
    end

    def expanded_hermes_home
      raw = user.try(:hermes_home).to_s.strip
      raw = "~/.hermes" if raw.empty?
      File.expand_path(raw)
    rescue StandardError
      nil
    end

    def timeout_seconds
      Integer(ENV.fetch("HERMES_COMMAND_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS.to_s))
    rescue ArgumentError
      DEFAULT_TIMEOUT_SECONDS
    end
  end
end
