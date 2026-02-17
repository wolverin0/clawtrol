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

  test "does not re-schedule when interval is not set" do
    ENV.stub(:[], ->(k) { nil }) do
      assert_no_enqueued_jobs do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end

  test "does not re-schedule when interval is zero" do
    ENV.stub(:[], ->(k) { k == "CLAWDECK_GUARDRAILS_INTERVAL_SECONDS" ? "0" : nil }) do
      assert_no_enqueued_jobs do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end

  test "does not re-schedule when interval is negative" do
    ENV.stub(:[], ->(k) { k == "CLAWDECK_GUARDRAILS_INTERVAL_SECONDS" ? "-1" : nil }) do
      assert_no_enqueued_jobs do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end

  test "re-schedules with correct interval when interval is positive" do
    ENV.stub(:[], ->(k) { k == "CLAWDECK_GUARDRAILS_INTERVAL_SECONDS" ? "60" : nil }) do
      assert_enqueued_with(job: CatastrophicGuardrailsJob, wait: 60.seconds) do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end
end
