# frozen_string_literal: true

require "test_helper"

class AutoClaimNotifyJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = Task.create!(name: "Auto Claim Test", board: @board, user: @user)
  end

  test "does not raise for missing task" do
    assert_nothing_raised do
      AutoClaimNotifyJob.perform_now(999_999)
    end
  end

  test "does not raise when user has no gateway configured" do
    assert_nothing_raised do
      AutoClaimNotifyJob.perform_now(@task.id)
    end
  end
end
