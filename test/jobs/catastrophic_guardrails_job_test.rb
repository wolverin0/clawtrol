# frozen_string_literal: true

require "test_helper"

class CatastrophicGuardrailsJobTest < ActiveJob::TestCase
  test "self reschedules when interval set" do
    ENV.stub(:[], ->(k) { k == "CLAWDECK_GUARDRAILS_INTERVAL_SECONDS" ? "60" : nil }) do
      service = Struct.new(:check!).new([])
      CatastrophicGuardrailsService.stub(:new, service) do
        assert_enqueued_with(job: CatastrophicGuardrailsJob) do
          CatastrophicGuardrailsJob.perform_now
        end
      end
    end
  end
end
