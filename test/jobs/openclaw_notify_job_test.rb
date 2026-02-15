# frozen_string_literal: true

require "test_helper"

class OpenclawNotifyJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = Task.create!(name: "Notify Test", board: @board, user: @user)
  end

  test "does not raise for missing task" do
    assert_nothing_raised do
      OpenclawNotifyJob.perform_now(999_999)
    end
  end

  test "does not raise when user has no gateway configured" do
    # User without gateway URL — webhook should silently skip
    assert_nothing_raised do
      OpenclawNotifyJob.perform_now(@task.id)
    end
  end
end
