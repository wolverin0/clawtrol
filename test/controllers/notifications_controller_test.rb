# frozen_string_literal: true

require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    reset!
    get notifications_path
    assert_response :redirect
  end

  test "index loads notifications page" do
    get notifications_path
    assert_response :success
  end

  test "mark_read marks notification as read" do
    notification = Notification.create!(
      user: @user,
      event_type: "task_completed",
      message: "Test notification"
    )
    assert_nil notification.read_at

    patch mark_read_notification_path(notification)

    notification.reload
    assert_not_nil notification.read_at
  end

  test "mark_read with turbo_stream format" do
    notification = Notification.create!(
      user: @user,
      event_type: "task_completed",
      message: "Turbo notification"
    )

    patch mark_read_notification_path(notification),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    notification.reload
    assert_not_nil notification.read_at
  end

  test "mark_read rejects other users notification" do
    other_user = users(:two)
    notification = Notification.create!(
      user: other_user,
      event_type: "task_completed",
      message: "Other user notification"
    )

    patch mark_read_notification_path(notification)
    assert_response :not_found
  end

  test "mark_all_read marks all unread notifications" do
    3.times do |i|
      Notification.create!(
        user: @user,
        event_type: "task_completed",
        message: "Notification #{i}"
      )
    end

    post mark_all_read_notifications_path
    assert_response :redirect

    assert_equal 0, @user.notifications.unread.count
  end

  test "mark_all_read does not affect other users" do
    other_user = users(:two)
    other_notif = Notification.create!(
      user: other_user,
      event_type: "task_completed",
      message: "Other notification"
    )

    post mark_all_read_notifications_path

    other_notif.reload
    assert_nil other_notif.read_at
  end

end
