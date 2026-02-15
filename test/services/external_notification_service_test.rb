require "test_helper"

class ExternalNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @old_bot_token = ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"]
    @old_fallback_chat = ENV["CLAWTROL_TELEGRAM_CHAT_ID"]
    @old_legacy_bot_token = ENV["TELEGRAM_BOT_TOKEN"]
    @old_legacy_chat = ENV["TELEGRAM_CHAT_ID"]

    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "test_bot_token"
    ENV["CLAWTROL_TELEGRAM_CHAT_ID"] = "-100999" # Mission Control
    ENV.delete("TELEGRAM_BOT_TOKEN")
    ENV.delete("TELEGRAM_CHAT_ID")

    @original_post_form = Net::HTTP.method(:post_form)
  end

  teardown do
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = @old_bot_token
    ENV["CLAWTROL_TELEGRAM_CHAT_ID"] = @old_fallback_chat
    ENV["TELEGRAM_BOT_TOKEN"] = @old_legacy_bot_token
    ENV["TELEGRAM_CHAT_ID"] = @old_legacy_chat

    Net::HTTP.define_singleton_method(:post_form, @original_post_form)
  end

  test "sends completion message to task origin topic when present" do
    task = tasks(:one)
    task.update!(origin_chat_id: "-100123", origin_thread_id: 77, status: "done")

    captured = nil
    Net::HTTP.define_singleton_method(:post_form) do |_uri, params|
      captured = params
      true
    end

    service = ExternalNotificationService.new(task)
    assert service.send(:telegram_configured?)

    service.notify_task_completion

    assert_not_nil captured
    assert_equal "-100123", captured[:chat_id]
    assert_equal 77, captured[:message_thread_id]
    assert captured[:text].include?("Task ##{task.id}"), "expected message to include task id"
  end

  test "falls back to Mission Control topic 1 when task origin missing" do
    task = tasks(:one)
    task.update!(origin_chat_id: nil, origin_thread_id: nil, status: "done")

    captured = nil
    Net::HTTP.define_singleton_method(:post_form) do |_uri, params|
      captured = params
      true
    end

    service = ExternalNotificationService.new(task)
    assert service.send(:telegram_configured?)

    service.notify_task_completion

    assert_not_nil captured
    assert_equal "-100999", captured[:chat_id]
    assert_equal 1, captured[:message_thread_id]
  end
end
