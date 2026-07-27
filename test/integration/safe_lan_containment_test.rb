# frozen_string_literal: true

require "test_helper"

class SafeLanContainmentTest < ActiveSupport::TestCase
  BLOCKED_REQUESTS = [
    ["POST", "/api/v1/hooks/agent_complete"],
    ["GET", "/api/v1/gateway/health"],
    ["POST", "/marketing/generate_image"],
    ["GET", "/zerobitch"],
    ["GET", "/webchat"],
    ["GET", "/keys"],
    ["POST", "/factory/1/play"],
    ["POST", "/boards/1/tasks/1/run_debate"]
  ].freeze

  test "legacy execution requests fail closed before routing" do
    downstream = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["reachable"]] }
    request = Rack::MockRequest.new(SafeLan::LegacyExecutionBlocker.new(downstream))

    SafeLan::LegacyExecutionPolicy.stub(:test_override?, false) do
      BLOCKED_REQUESTS.each do |method, path|
        response = request.request(method, path)

        assert_equal 410, response.status, "#{method} #{path}"
        assert_equal "no-store", response["Cache-Control"]
        assert_equal "nosniff", response["X-Content-Type-Options"]
      end
    end
  end

  test "ordinary bearer authenticated task API remains outside legacy guard" do
    downstream = ->(_env) { [401, { "Content-Type" => "application/json" }, ['{"error":"Unauthorized"}']] }
    request = Rack::MockRequest.new(SafeLan::LegacyExecutionBlocker.new(downstream))

    SafeLan::LegacyExecutionPolicy.stub(:test_override?, false) do
      response = request.post("/api/v1/tasks/1/agent_complete")
      assert_equal 401, response.status
      refute_includes response.body, "safe_lan_legacy_execution_disabled"
    end
  end

  test "retired jobs cannot run" do
    SafeLan::LegacyExecutionPolicy.stub(:test_override?, false) do
      error = assert_raises(SafeLan::LegacyExecutionDisabled) do
        SafeLan::LegacyExecutionPolicy.enforce_job!("NightshiftRunnerJob")
      end
      assert_includes error.message, "retired"
    end
  end
end
