# frozen_string_literal: true

require "open3"
require "timeout"

class FactoryPromotionGateService
  CHECK_TIMEOUT_SECONDS = 300
  BASE_CHECKS = [
    { name: "syntax_check", command: "git diff --name-only -- '*.rb' | xargs -r ruby -c" },
    { name: "test_command", command: "bin/rails test" }
  ].freeze
  E2E_CHECK = { name: "e2e_command", command: "bin/rails test:system" }.freeze

  Result = Struct.new(:name, :success, :output, keyword_init: true)

  class << self
    def verify!(repo_path, include_e2e: false)
      normalized_repo_path = normalize_repo_path(repo_path)
      unless normalized_repo_path
        return {
          success: false,
          message: "Promotion gate failed",
          checks: [Result.new(name: "repo_path", success: false, output: "Repository path is not accessible").to_h]
        }
      end

      checks = check_definitions(include_e2e:).map do |check|
        run_check(
          name: check[:name],
          command: check[:command],
          repo_path: normalized_repo_path
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

    def check_definitions(include_e2e:)
      include_e2e ? BASE_CHECKS + [E2E_CHECK] : BASE_CHECKS
    end

    def normalize_repo_path(repo_path)
      expanded_path = File.expand_path(repo_path.to_s)
      return expanded_path if File.directory?(expanded_path)

      nil
    end

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
