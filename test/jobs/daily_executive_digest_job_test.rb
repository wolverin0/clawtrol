# frozen_string_literal: true

require "test_helper"

class DailyExecutiveDigestJobTest < ActiveJob::TestCase
  def setup
    @user1 = users(:one)
    @user2 = users(:two)
  end

  test "calls DailyExecutiveDigestService for each user" do
    calls = []

    # Stub the service to record calls
    DailyExecutiveDigestService.stub(:new, ->(user) {
      calls << user
      mock_service = Object.new
      def mock_service.call; end
      mock_service
    }) do
      DailyExecutiveDigestJob.perform_now
    end

    # All users should have been processed
    assert_equal User.count, calls.size
    assert_includes calls, @user1
    assert_includes calls, @user2
  end
end
