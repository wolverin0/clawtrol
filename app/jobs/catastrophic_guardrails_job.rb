# frozen_string_literal: true

class CatastrophicGuardrailsJob < ApplicationJob
  queue_as :default

  def perform(source: "periodic")
    CatastrophicGuardrailsService.new(source: source).check!

    interval = ENV["CLAWDECK_GUARDRAILS_INTERVAL_SECONDS"].to_i
    return unless interval.positive?

    self.class.set(wait: interval.seconds).perform_later(source: "periodic")
  end
end
