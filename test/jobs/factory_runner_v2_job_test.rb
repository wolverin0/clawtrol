# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "shellwords"

class FactoryRunnerV2JobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "runner_v2@example.com", password: "password123456")
  end

  test "runs active loops, creates cycle log + agent run and updates status" do
    Dir.mktmpdir do |dir|
      system("bash", "-lc", "cd #{Shellwords.escape(dir)} && git init -q && git config user.email 'test@example.com' && git config user.name 'Test User' && echo hi > README.md && git add README.md && git commit -m init -q")

      loop = FactoryLoop.create!(
        name: "Runner Loop #{SecureRandom.hex(3)}",
        slug: "runner-loop-#{SecureRandom.hex(3)}",
        interval_ms: 60_000,
        model: "minimax",
        status: "idle",
        workspace_path: dir,
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
      assert_not_nil run.finished_at

      cycle_log = FactoryCycleLog.where(factory_loop: loop).order(created_at: :desc).first
      assert_not_nil cycle_log
      assert_includes %w[completed failed], cycle_log.status
      assert_equal agent.name, cycle_log.agent_name
    end
  end

  test "uses least recently run agent when last_run_at column does not exist" do
    Dir.mktmpdir do |dir|
      system("bash", "-lc", "cd #{Shellwords.escape(dir)} && git init -q && git config user.email 'test@example.com' && git config user.name 'Test User' && echo hi > README.md && git add README.md && git commit -m init -q")

      loop = FactoryLoop.create!(
        name: "Rotation Loop #{SecureRandom.hex(3)}",
        slug: "rotation-loop-#{SecureRandom.hex(3)}",
        interval_ms: 60_000,
        model: "minimax",
        status: "idle",
        workspace_path: dir,
        user: @user
      )

      a1 = FactoryAgent.create!(name: "A1 #{SecureRandom.hex(2)}", slug: "a1-#{SecureRandom.hex(4)}", category: "testing", system_prompt: "A1", run_condition: "always", cooldown_hours: 1, default_confidence_threshold: 80, priority: 5)
      a2 = FactoryAgent.create!(name: "A2 #{SecureRandom.hex(2)}", slug: "a2-#{SecureRandom.hex(4)}", category: "testing", system_prompt: "A2", run_condition: "always", cooldown_hours: 1, default_confidence_threshold: 80, priority: 5)

      FactoryLoopAgent.create!(factory_loop: loop, factory_agent: a1, enabled: true)
      FactoryLoopAgent.create!(factory_loop: loop, factory_agent: a2, enabled: true)

      FactoryAgentRun.create!(factory_loop: loop, factory_agent: a1, status: "clean", started_at: 1.minute.ago, finished_at: 1.minute.ago)

      FactoryRunnerV2Job.perform_now

      latest = FactoryAgentRun.where(factory_loop: loop).order(created_at: :desc).first
      assert_equal a2.id, latest.factory_agent_id
    end
  end
end
