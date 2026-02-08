# frozen_string_literal: true

namespace :clawdeck do
  desc "Auto-run Up Next tasks by waking OpenClaw + apply zombie guardrails"
  task agent_auto_runner: :environment do
    AgentAutoRunnerService.new.run!
  end
end
