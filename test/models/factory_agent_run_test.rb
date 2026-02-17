require "test_helper"

class FactoryAgentRunTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "test-run@example.com", password: "password123")
    @loop = FactoryLoop.create!(name: "Test Loop", slug: "test-loop-run", interval_ms: 60000, model: "flash", status: "idle", user: @user)
    @agent = FactoryAgent.create!(name: "Test Agent", slug: "test-agent-run", system_prompt: "test", run_condition: "always")
    @run = FactoryAgentRun.new(factory_loop: @loop, factory_agent: @agent, status: "clean")
  end

  test "valid with required associations" do
    assert @run.valid?
  end

  test "invalid without factory_loop" do
    @run.factory_loop = nil
    assert_not @run.valid?
  end

  test "invalid without factory_agent" do
    @run.factory_agent = nil
    assert_not @run.valid?
  end

  test "status must be in allowed list" do
    @run.status = "invalid"
    assert_not @run.valid?
  end

  test "findings_count must be non-negative" do
    @run.findings_count = -1
    assert_not @run.valid?
  end

  test "duration_seconds calculated correctly" do
    @run.started_at = Time.current
    @run.finished_at = @run.started_at + 120.seconds
    assert_equal 120, @run.duration_seconds
  end

  test "duration_seconds nil when timestamps missing" do
    assert_nil @run.duration_seconds
  end

  test "scopes filter correctly" do
    @run.save!
    finding_run = FactoryAgentRun.create!(factory_loop: @loop, factory_agent: @agent, status: "findings", findings_count: 2)
    error_run = FactoryAgentRun.create!(factory_loop: @loop, factory_agent: @agent, status: "error")

    assert_includes FactoryAgentRun.clean, @run
    assert_includes FactoryAgentRun.with_findings, finding_run
    assert_includes FactoryAgentRun.errored, error_run
  end
end
