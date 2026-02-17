# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class FactoryPromptCompilerTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "factory_prompt@example.com", password: "password123456")
  end

  test "includes system prompt, stack, backlog, improvements and patterns" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "FACTORY_BACKLOG.md"), "- [ ] pending item\n- [x] done item\n")

      loop = FactoryLoop.create!(
        name: "Prompt Loop #{SecureRandom.hex(3)}",
        slug: "prompt-loop-#{SecureRandom.hex(3)}",
        interval_ms: 60_000,
        model: "minimax",
        status: "idle",
        workspace_path: dir,
        user: @user
      )

      loop.factory_cycle_logs.create!(cycle_number: 1, started_at: 2.hours.ago, finished_at: 2.hours.ago + 1.minute, status: "completed", summary: "Fix flaky tests")
      loop.factory_cycle_logs.create!(cycle_number: 2, started_at: 1.hour.ago, finished_at: 1.hour.ago + 1.minute, status: "completed", summary: "Improve error handling")

      agent = FactoryAgent.create!(
        name: "Agent #{SecureRandom.hex(2)}",
        slug: "agent-#{SecureRandom.hex(4)}",
        category: "code-quality",
        system_prompt: "Improve code safely",
        run_condition: "always",
        cooldown_hours: 1,
        default_confidence_threshold: 80,
        priority: 5
      )

      FactoryFindingPattern.create!(
        factory_loop: loop,
        pattern_hash: SecureRandom.hex(16),
        category: "bug-fix",
        description: "nil-check missing"
      )

      prompt = FactoryPromptCompiler.call(
        factory_loop: loop,
        factory_agent: agent,
        stack_info: { framework: "rails", language: "ruby", test_command: "bin/rails test", syntax_check: "ruby -c" }
      )

      assert_includes prompt, "Improve code safely"
      assert_includes prompt, "framework: rails"
      assert_includes prompt, "pending item"
      assert_not_includes prompt, "done item"
      assert_includes prompt, "Improve error handling"
      assert_includes prompt, "nil-check missing"
    end
  end
end
