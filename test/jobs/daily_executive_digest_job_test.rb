# frozen_string_literal: true

require "test_helper"

class DailyExecutiveDigestJobTest < ActiveJob::TestCase
  test "calls DailyExecutiveDigestService" do
    called = false
    DailyExecutiveDigestService.stub(:call, -> { called = true }) do
      DailyExecutiveDigestJob.perform_now
    end
    assert called
  end
end
