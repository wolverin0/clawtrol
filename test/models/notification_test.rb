require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "create_deduped! suppresses identical event_type+task within dedup window" do
    user = users(:one)
    task = tasks(:one)

    travel_to Time.utc(2026, 2, 9, 12, 0, 0) do
      first = Notification.create_deduped!(user: user, task: task, event_type: "auto_pull_error", message: "boom")
      assert first.present?

      second = Notification.create_deduped!(user: user, task: task, event_type: "auto_pull_error", message: "boom again")
      assert_nil second

      assert_equal 1, Notification.where(user: user, task: task, event_type: "auto_pull_error").where("created_at >= ?", 10.minutes.ago).count
    end
  end

  test "cap purges oldest notifications beyond CAP_PER_USER" do
    user = users(:one)

    Notification.where(user: user).delete_all

    (Notification::CAP_PER_USER + 10).times do |i|
      Notification.create!(user: user, event_type: "auto_runner", message: "n#{i}")
    end

    assert_equal Notification::CAP_PER_USER, Notification.where(user: user).count
  end
end
