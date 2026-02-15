# frozen_string_literal: true

require "test_helper"

class OpenclawCliRunnableTest < ActiveSupport::TestCase
  # Create a test class that includes the concern
  class TestController
    include OpenclawCliRunnable

    # Make private methods accessible for testing
    public :run_openclaw_cli, :run_openclaw_cli_json, :ms_to_time, :openclaw_timeout_seconds
  end

  setup do
    @controller = TestController.new
  end

  # --- ms_to_time ---

  test "ms_to_time converts milliseconds to Time" do
    time = @controller.ms_to_time(1_700_000_000_000)
    assert_kind_of Time, time
    assert_in_delta 1_700_000_000, time.to_f, 1
  end

  test "ms_to_time returns nil for nil input" do
    assert_nil @controller.ms_to_time(nil)
  end

  test "ms_to_time returns nil for blank string" do
    assert_nil @controller.ms_to_time("")
  end

  test "ms_to_time handles string input" do
    time = @controller.ms_to_time("1700000000000")
    assert_kind_of Time, time
  end

  # --- openclaw_timeout_seconds ---

  test "openclaw_timeout_seconds defaults to 20" do
    ENV.delete("OPENCLAW_COMMAND_TIMEOUT_SECONDS")
    assert_equal 20, @controller.openclaw_timeout_seconds
  end

  test "openclaw_timeout_seconds reads from ENV" do
    ENV["OPENCLAW_COMMAND_TIMEOUT_SECONDS"] = "30"
    assert_equal 30, @controller.openclaw_timeout_seconds
  ensure
    ENV.delete("OPENCLAW_COMMAND_TIMEOUT_SECONDS")
  end

  test "openclaw_timeout_seconds defaults to 20 for invalid ENV" do
    ENV["OPENCLAW_COMMAND_TIMEOUT_SECONDS"] = "not_a_number"
    assert_equal 20, @controller.openclaw_timeout_seconds
  ensure
    ENV.delete("OPENCLAW_COMMAND_TIMEOUT_SECONDS")
  end

  # --- run_openclaw_cli ---

  test "run_openclaw_cli returns structured result hash" do
    # This will fail (openclaw not installed in test env) but should return structured result
    result = @controller.run_openclaw_cli("--version")

    assert_kind_of Hash, result
    assert result.key?(:stdout)
    assert result.key?(:stderr)
    assert result.key?(:exitstatus)
  end

  # --- run_openclaw_cli_json ---

  test "run_openclaw_cli_json returns offline status when CLI is missing" do
    # openclaw likely not in test PATH
    result = @controller.run_openclaw_cli_json("--version", label: "test")

    assert_kind_of Hash, result
    # Either "offline" with error, or actual data if openclaw happens to be installed
    if result[:status] == "offline"
      assert result[:error].present?
    end
  end
end
