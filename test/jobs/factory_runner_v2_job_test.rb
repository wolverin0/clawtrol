# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "shellwords"

class FactoryRunnerV2JobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "runner_v2@example.com", password: "password123456")
  end

  test "iterates active loops and creates run records" do
    Dir.mktmpdir do |dir|
      system("bash", "-lc", "cd #{Shellwords.escape(dir)} && git init -q && git config user.email 'test@example.com' && git config user.name 'Test User' && touch README.md && git add README.md && git commit -m init -q")

      loop = FactoryLoop.create!(
        name: "Runner Loop #{SecureRandom.hex(3)}",
        slug: "runner-loop-#{SecureRandom.hex(3)}",
        interval_ms: 60_000,
        model: "minimax",
        status: "idle",
        workspace_path: dir,
        idle_policy: "maintenance",
        user: @user
      )

      agent = FactoryAgent.create!(
        name: "Runner Agent #{SecureRandom.hex(2)}",
        slug: "runner-agent-#{SecureRandom.hex(4)}",
        category: "code-quality",
        system_prompt: "Find and fix issues",
        run_condition: "always",
        cooldown_hours: 1,
        default_confidence_threshold: 80,
        priority: 5
      )

      FactoryLoopAgent.create!(factory_loop: loop, factory_agent: agent, enabled: true)

      FactoryRunnerV2Job.perform_now

      run = FactoryAgentRun.where(factory_loop: loop, factory_agent: agent).order(created_at: :desc).first
      assert_not_nil run
      assert_includes %w[clean findings error], run.status

      cycle_log = FactoryCycleLog.where(factory_loop: loop).order(created_at: :desc).first
      assert_not_nil cycle_log
      assert_includes %w[completed failed], cycle_log.status
    end
  end

  test "skips pause policy loops when recently active" do
    Dir.mktmpdir do |dir|
      loop = FactoryLoop.create!(
        name: "Paused Loop #{SecureRandom.hex(3)}",
        slug: "paused-loop-#{SecureRandom.hex(3)}",
        interval_ms: 60_000,
        model: "minimax",
        status: "idle",
        workspace_path: dir,
        idle_policy: "pause",
        last_cycle_at: 5.minutes.ago,
        user: @user
      )

      agent = FactoryAgent.create!(
        name: "Paused Agent #{SecureRandom.hex(2)}",
        slug: "paused-agent-#{SecureRandom.hex(4)}",
        category: "testing",
        system_prompt: "Run tests",
        run_condition: "always",
        cooldown_hours: 1,
        default_confidence_threshold: 80,
        priority: 5
      )

      FactoryLoopAgent.create!(factory_loop: loop, factory_agent: agent, enabled: true)

      assert_no_difference("FactoryAgentRun.count") do
        FactoryRunnerV2Job.perform_now
      end
    end
  end
end
