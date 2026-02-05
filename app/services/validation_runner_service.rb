require "open3"
require "shellwords"

# Centralized service for running validation commands against tasks.
# Used by:
#   - Boards::TasksController#execute_validation_command (web revalidation)
#   - Api::V1::TasksController#run_validation_command (API legacy revalidation)
#   - RunValidationJob#perform (background review validation)
class ValidationRunnerService
  Result = Struct.new(:success?, :output, :exit_code, :error, keyword_init: true)

  DEFAULT_TIMEOUT = 60   # seconds for inline (controller) calls
  REVIEW_TIMEOUT  = 120  # seconds for background review jobs
  MAX_OUTPUT_SIZE = 65_535

  def initialize(task, timeout: DEFAULT_TIMEOUT)
    @task = task
    @timeout = timeout
  end

  # Run the validation command and update the task in place.
  # Returns a Result struct.
  def call
    command = @task.validation_command
    return Result.new(success?: false, output: "No validation command configured", exit_code: -1) unless command.present?

    @task.update!(validation_status: "pending")

    begin
      output = nil
      exit_status = nil

      Timeout.timeout(@timeout) do
        # Security: use Shellwords.shellsplit to prevent shell metacharacter injection
        output, exit_status = Open3.capture2e(*Shellwords.shellsplit(command), chdir: Rails.root.to_s)
      end

      truncated_output = output.to_s.truncate(MAX_OUTPUT_SIZE)
      @task.validation_output = truncated_output

      if exit_status&.success?
        @task.validation_status = "passed"
        @task.status = "in_review"
      else
        @task.validation_status = "failed"
        @task.status = "in_progress"
      end

      @task.save!

      Result.new(
        success?: exit_status&.success? || false,
        output: truncated_output,
        exit_code: exit_status&.exitstatus || -1
      )
    rescue Timeout::Error
      @task.update!(
        validation_status: "failed",
        validation_output: "Validation command timed out after #{@timeout} seconds",
        status: "in_progress"
      )
      Result.new(success?: false, output: "Validation command timed out after #{@timeout} seconds", exit_code: -1, error: "timeout")
    rescue StandardError => e
      @task.update!(
        validation_status: "failed",
        validation_output: "Error running validation: #{e.message}",
        status: "in_progress"
      )
      Result.new(success?: false, output: "Error running validation: #{e.message}", exit_code: -1, error: e.message)
    end
  end

  # Run as a review (used by RunValidationJob).
  # Updates review_status/review_result in addition to validation fields.
  def call_as_review
    command = @task.review_config["command"] || @task.validation_command
    return unless command.present?

    # Ensure validation_command is set for the runner
    @task.update!(validation_command: command) unless @task.validation_command == command

    result = call

    if result.success?
      @task.complete_review!(
        status: "passed",
        result: {
          exit_code: result.exit_code,
          output_preview: result.output.to_s.truncate(500)
        }
      )
    else
      error_summary = if result.error == "timeout"
        "Validation command timed out after #{@timeout} seconds"
      else
        "Validation command failed with exit code #{result.exit_code}"
      end

      @task.complete_review!(
        status: "failed",
        result: {
          exit_code: result.exit_code,
          output_preview: result.output.to_s.truncate(500),
          error_summary: error_summary,
          timeout: result.error == "timeout"
        }.compact
      )
    end

    result
  end
end
