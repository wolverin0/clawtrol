# frozen_string_literal: true

require "open3"
require "timeout"

class FactoryPromotionGateService
  CHECK_TIMEOUT_SECONDS = 300

  Result = Struct.new(:name, :success, :output, keyword_init: true)

  class << self
    def verify!(repo_path, include_e2e: false)
      checks = []

      checks << run_check(
        name: "syntax_check",
        command: "git diff --name-only -- '*.rb' | xargs -r ruby -c",
        repo_path: repo_path
      )

      checks << run_check(
        name: "test_command",
        command: "bin/rails test",
        repo_path: repo_path
      )

      if include_e2e
        checks << run_check(
          name: "e2e_command",
          command: "bin/rails test:system",
          repo_path: repo_path
        )
      end

      success = checks.all?(&:success)
      message = success ? "Promotion gate passed" : "Promotion gate failed"

      {
        success: success,
        message: message,
        checks: checks.map { |check| check.to_h }
      }
    end

    private

    def run_check(name:, command:, repo_path:)
      output = ""
      success = false

      Timeout.timeout(CHECK_TIMEOUT_SECONDS) do
        stdout, stderr, status = Open3.capture3("bash", "-lc", command, chdir: repo_path)
        output = [stdout, stderr].compact.join("\n").truncate(50_000)
        success = status.success?
      end

      Result.new(name: name, success: success, output: output)
    rescue Timeout::Error
      Result.new(name: name, success: false, output: "Timed out after #{CHECK_TIMEOUT_SECONDS}s")
    rescue StandardError => e
      Result.new(name: name, success: false, output: "#{e.class}: check execution failed")
    end
  end
end
