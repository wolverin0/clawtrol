# frozen_string_literal: true

require "test_helper"

class ValidationRunnerServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = @board.tasks.create!(
      name: "Validation test task",
      user: @user,
      status: :in_progress,
      validation_command: "bin/rails test --help"
    )
  end

  # --- No command configured ---

  test "returns failure when no validation command" do
    @task.update!(validation_command: nil)
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_not result.success?
    assert_equal(-1, result.exit_code)
    assert_match(/no validation command/i, result.output)
  end

  test "returns failure for empty validation command" do
    @task.update!(validation_command: "")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_not result.success?
  end

  # --- Command allowlist ---

  test "blocks commands not in allowlist" do
    # Use update_column to bypass model-level validation (test service-level check)
    @task.update_column(:validation_command, "curl http://evil.com")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_not result.success?
    assert_equal "blocked", result.error
    assert_match(/allowlist/i, result.output)
  end

  test "blocks rm commands" do
    @task.update_column(:validation_command, "rm -rf /")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_not result.success?
    assert_equal "blocked", result.error
  end

  test "allows bin/rails commands" do
    service = ValidationRunnerService.new(@task)
    # We can test that it's allowed even if the command might fail
    result = service.call
    # The command should be allowed (not blocked) even if it fails
    assert_not_equal "blocked", result.error
  end

  test "allows node commands" do
    @task.update!(validation_command: "node --version")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_not_equal "blocked", result.error
  end

  test "allows ruby commands" do
    @task.update!(validation_command: "ruby -e 'puts 42'")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert result.success?
    assert_match(/42/, result.output)
  end

  # --- Successful execution ---

  test "successful command sets validation_status to passed" do
    @task.update!(validation_command: "ruby -e 'puts :ok'")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert result.success?
    assert_equal 0, result.exit_code
    @task.reload
    assert_equal "passed", @task.validation_status
  end

  test "successful command captures output" do
    @task.update!(validation_command: "ruby -e 'puts :hello_world'")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_match(/hello_world/, result.output)
    @task.reload
    assert_match(/hello_world/, @task.validation_output)
  end

  # --- Failed execution ---

  test "failing command sets validation_status to failed" do
    @task.update!(validation_command: "ruby -e 'exit 1'")
    service = ValidationRunnerService.new(@task)
    result = service.call

    assert_not result.success?
    assert_equal 1, result.exit_code
    @task.reload
    assert_equal "failed", @task.validation_status
    assert_equal "in_progress", @task.status
  end

  # --- Timeout ---

  test "timeout returns failure with timeout error" do
    @task.update!(validation_command: "ruby -e 'sleep 5'")
    service = ValidationRunnerService.new(@task, timeout: 1)
    result = service.call

    assert_not result.success?
    assert_equal "timeout", result.error
    assert_match(/timed out/i, result.output)
    @task.reload
    assert_equal "failed", @task.validation_status
  end

  # --- Constants ---

  test "has sensible default constants" do
    assert_equal 60, ValidationRunnerService::DEFAULT_TIMEOUT
    assert_equal 120, ValidationRunnerService::REVIEW_TIMEOUT
    assert_equal 65_535, ValidationRunnerService::MAX_OUTPUT_SIZE
  end

  test "ALLOWED_COMMAND_PREFIXES includes common tools" do
    prefixes = ValidationRunnerService::ALLOWED_COMMAND_PREFIXES
    assert_includes prefixes, "bin/rails"
    assert_includes prefixes, "node"
    assert_includes prefixes, "ruby"
    assert_includes prefixes, "npm"
  end
end
