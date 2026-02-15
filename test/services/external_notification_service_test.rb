# frozen_string_literal: true

require "test_helper"

class ExternalNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = @board.tasks.create!(
      user: @user,
      name: "Test notification task",
      description: "Some description",
      status: :in_review
    )
    @service = ExternalNotificationService.new(@task)
  end

  # --- Format ---

  test "format_message includes task id and status" do
    msg = @service.send(:format_message)
    assert_includes msg, "##{@task.id}"
    assert_includes msg, "In review"
    assert_includes msg, @task.name
  end

  test "format_message uses review emoji for in_review status" do
    msg = @service.send(:format_message)
    assert_includes msg, "📋"
  end

  test "format_message uses check emoji for done status" do
    @task.update_columns(status: Task.statuses[:done])
    msg = @service.send(:format_message)
    assert_includes msg, "✅"
  end

  test "format_message truncates long descriptions" do
    @task.update_columns(description: "x" * 1000)
    msg = @service.send(:format_message)
    assert msg.length < 1000
  end

  # --- Telegram ---

  test "telegram_configured? returns false without bot token" do
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
    assert_not @service.send(:telegram_configured?)
  end

  test "telegram_configured? returns false without origin_chat_id" do
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "test_token"
    # origin_chat_id is nil by default
    assert_not @service.send(:telegram_configured?)
  ensure
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
  end

  test "telegram_configured? returns true when both present" do
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "test_token"
    @task.update_columns(origin_chat_id: "12345") if @task.respond_to?(:origin_chat_id)
    result = @service.send(:telegram_configured?)
    if @task.respond_to?(:origin_chat_id)
      assert result
    else
      assert_not result
    end
  ensure
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
  end

  # --- Webhook ---

  test "webhook_configured? returns false when user has no webhook_notification_url" do
    assert_not @service.send(:webhook_configured?)
  end

  test "webhook_configured? returns true when user has webhook_notification_url" do
    if @user.respond_to?(:webhook_notification_url=)
      @user.update!(webhook_notification_url: "https://example.com/hook")
      assert @service.send(:webhook_configured?)
    else
      skip "User does not have webhook_notification_url column"
    end
  end

  # --- notify_task_completion ---

  test "notify_task_completion does not raise when nothing configured" do
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
    # Should be a no-op, not raise
    assert_nothing_raised { @service.notify_task_completion }
  end

  test "webhook_configured? requires valid webhook_notification_url on user" do
    if @user.respond_to?(:webhook_notification_url)
      assert_not @service.send(:webhook_configured?)
      @user.update_columns(webhook_notification_url: "https://example.com/hook")
      assert @service.send(:webhook_configured?)
    else
      assert_not @service.send(:webhook_configured?)
    end
  end

  test "telegram send does not raise even with invalid token" do
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "fake_token_12345"
    if @task.class.column_names.include?("origin_chat_id")
      @task.update_columns(origin_chat_id: "12345")
      service = ExternalNotificationService.new(@task)
      assert service.send(:telegram_configured?)
      # send_telegram catches all exceptions
      assert_nothing_raised { service.send(:send_telegram) }
    else
      skip "Task does not have origin_chat_id column"
    end
  ensure
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
  end

  # --- Edge cases ---

  test "handles task with nil description" do
    @task.update_columns(description: nil)
    msg = @service.send(:format_message)
    assert_includes msg, @task.name
    assert_not_nil msg
  end

  test "handles task with blank name" do
    @task.update_columns(name: "")
    msg = @service.send(:format_message)
    assert_not_nil msg
  end
end
