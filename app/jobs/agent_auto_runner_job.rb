# frozen_string_literal: true

class AgentAutoRunnerJob < ApplicationJob
  queue_as :default

  # Discard if stuck in a loop — auto-runner is periodic, next run will pick up
  discard_on StandardError do |job, error|
    Rails.logger.error("[AgentAutoRunnerJob] Discarded: #{error.class}: #{error.message}")
  end

  def perform
    AgentAutoRunnerService.new.run!
  end
end
