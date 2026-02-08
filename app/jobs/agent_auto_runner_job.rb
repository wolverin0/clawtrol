# frozen_string_literal: true

class AgentAutoRunnerJob < ApplicationJob
  queue_as :default

  def perform
    AgentAutoRunnerService.new.run!
  end
end
