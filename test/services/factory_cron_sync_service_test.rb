# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open3"

class FactoryCronSyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "factory-cron-sync@example.com", password: "password123456")
  end

  test "create_cron stores returned cron id on loop" do
    with_loop_and_agent do |loop|
      fake_json = { "id" => "cron-abc-123" }.to_json

      with_stubbed_cli(output: fake_json) do
        result = FactoryCronSyncService.create_cron(loop)

        assert_equal "cron-abc-123", result["id"]
        assert_equal "cron-abc-123", loop.reload.openclaw_cron_id
      end
    end
  end

  test "create_cron returns empty hash when CLI is unavailable" do
    with_loop_and_agent do |loop|
      with_cli_unavailable do
        result = FactoryCronSyncService.create_cron(loop)
        assert_equal({}, result)
      end
    end
  end

  test "pause_cron does nothing when no cron_id" do
    loop = build_loop
    # No openclaw_cron_id set — should be a no-op
    assert_nothing_raised do
      with_cli_unavailable { FactoryCronSyncService.pause_cron(loop) }
    end
  end

  test "pause_cron calls disable when cron_id present" do
    loop = build_loop(openclaw_cron_id: "cron-1")
    called_cmds = []

    with_stubbed_run_cli(called_cmds) do
      FactoryCronSyncService.pause_cron(loop)
    end

    assert_includes called_cmds.first, "cron"
    assert_includes called_cmds.first, "disable"
    assert_includes called_cmds.first, "cron-1"
  end

  test "resume_cron calls enable when cron_id present" do
    loop = build_loop(openclaw_cron_id: "cron-2")
    called_cmds = []

    with_stubbed_run_cli(called_cmds) do
      FactoryCronSyncService.resume_cron(loop)
    end

    assert_includes called_cmds.first, "cron"
    assert_includes called_cmds.first, "enable"
    assert_includes called_cmds.first, "cron-2"
  end

  test "delete_cron clears openclaw_cron_id" do
    loop = build_loop(openclaw_cron_id: "cron-3")
    called_cmds = []

    with_stubbed_run_cli(called_cmds) do
      FactoryCronSyncService.delete_cron(loop)
    end

    assert_nil loop.reload.openclaw_cron_id
    assert_includes called_cmds.first, "rm"
    assert_includes called_cmds.first, "cron-3"
  end

  test "delete_cron does nothing when no cron_id" do
    loop = build_loop
    assert_nothing_raised do
      with_cli_unavailable { FactoryCronSyncService.delete_cron(loop) }
    end
    assert_nil loop.reload.openclaw_cron_id
  end

  private

  def build_loop(attrs = {})
    FactoryLoop.create!({
      name: "Factory Cron #{SecureRandom.hex(3)}",
      slug: "factory-cron-#{SecureRandom.hex(4)}",
      interval_ms: 120_000,
      model: "minimax",
      status: "idle",
      workspace_path: Dir.mktmpdir,
      max_session_minutes: 180,
      user: @user
    }.merge(attrs))
  end

  def with_loop_and_agent
    loop = build_loop
    agent = FactoryAgent.create!(
      name: "Agent #{SecureRandom.hex(2)}",
      slug: "agent-#{SecureRandom.hex(4)}",
      category: "code-quality",
      system_prompt: "Keep improving safely",
      run_condition: "always",
      cooldown_hours: 1,
      default_confidence_threshold: 80,
      priority: 1
    )
    FactoryLoopAgent.create!(factory_loop: loop, factory_agent: agent, enabled: true)

    yield loop
  end

  # Stubs cli_available? to return true and Open3.capture2 to return fake output
  def with_stubbed_cli(output: "{}", success: true)
    fake_status = Struct.new(:success?, :exitstatus).new(success, success ? 0 : 1)
    original_capture2 = Open3.method(:capture2)
    Open3.define_singleton_method(:capture2) { |*| [output, fake_status] }
    override_cli_available!(true) { yield }
  ensure
    Open3.define_singleton_method(:capture2, original_capture2)
  end

  # Stubs cli_available? to return false (CLI not installed)
  def with_cli_unavailable(&block)
    override_cli_available!(false, &block)
  end

  # Stubs run_cli to record calls instead of running the binary
  def with_stubbed_run_cli(called_cmds, &block)
    original = FactoryCronSyncService.method(:run_cli)
    FactoryCronSyncService.define_singleton_method(:run_cli) do |*cmd|
      called_cmds << cmd.join(" ")
      ""
    end
    block.call
  ensure
    FactoryCronSyncService.define_singleton_method(:run_cli, original)
  end

  def override_cli_available!(value)
    original = FactoryCronSyncService.method(:cli_available?)
    FactoryCronSyncService.define_singleton_method(:cli_available?) { |*| value }
    yield
  ensure
    FactoryCronSyncService.define_singleton_method(:cli_available?, original)
  end
end
