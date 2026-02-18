# frozen_string_literal: true

require "test_helper"

class CatastrophicGuardrailsJobTest < ActiveJob::TestCase
  def with_guardrails_interval(value)
    original = ENV.fetch("CLAWDECK_GUARDRAILS_INTERVAL_SECONDS", nil)
    ENV["CLAWDECK_GUARDRAILS_INTERVAL_SECONDS"] = value
    yield
  ensure
    if original.nil?
      ENV.delete("CLAWDECK_GUARDRAILS_INTERVAL_SECONDS")
    else
      ENV["CLAWDECK_GUARDRAILS_INTERVAL_SECONDS"] = original
    end
  end

  test "self reschedules when interval set" do
    with_guardrails_interval("60") do
      service = Struct.new(:check!).new([])
      CatastrophicGuardrailsService.stub(:new, service) do
        assert_enqueued_with(job: CatastrophicGuardrailsJob) do
          CatastrophicGuardrailsJob.perform_now
        end
      end
    end
  end

  test "does not re-schedule when interval is not set" do
    with_guardrails_interval(nil) do
      # ENV.delete done in helper when nil passed
      assert_no_enqueued_jobs do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end

  test "does not re-schedule when interval is zero" do
    with_guardrails_interval("0") do
      assert_no_enqueued_jobs do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end

  test "does not re-schedule when interval is negative" do
    with_guardrails_interval("-1") do
      assert_no_enqueued_jobs do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end

  test "re-schedules with correct interval when interval is positive" do
    with_guardrails_interval("60") do
      assert_enqueued_with(job: CatastrophicGuardrailsJob) do
        CatastrophicGuardrailsJob.perform_now
      end
    end
  end
end
