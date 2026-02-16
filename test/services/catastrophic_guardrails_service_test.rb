# frozen_string_literal: true

require "test_helper"

class CatastrophicGuardrailsServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.delete("clawdeck:guardrails:last_counts")
  end

  test "alerts when users table is empty" do
    # Ensure no users exist
    User.delete_all

    notifications_before = Notification.count

    ENV.stub(:[], ->(k) {
      {
        "CLAWTROL_TELEGRAM_BOT_TOKEN" => "test-token",
        "CLAWTROL_TELEGRAM_ALERT_CHAT_ID" => "123"
      }[k]
    }) do
      Net::HTTP.stub(:post_form, ->(_uri, _params) { true }) do
        events = CatastrophicGuardrailsService.new.check!
        assert events.any? { |e| e[:kind] == "users_empty" }
      end
    end

    assert_equal notifications_before, Notification.count, "Should not create Notification when there is no user to attach it to"
  end

  test "alerts on abrupt tasks drop" do
    user = User.create!(email_address: "a@example.com", password: "password1", password_confirmation: "password1", theme: "default", context_threshold_percent: 70)
    board = Board.create!(user: user, name: "B1", position: 0, color: "blue")

    10.times do |i|
      Task.create!(user: user, board: board, name: "T#{i}", status: "inbox", position: i)
    end

    # Seed snapshot
    CatastrophicGuardrailsService.new.check!

    Task.limit(8).delete_all

    ENV.stub(:fetch, ->(k, default = nil) {
      { "CLAWDECK_GUARDRAILS_DROP_PERCENT" => "50" }[k] || default
    }) do
      ENV.stub(:[], ->(k) {
        {
          "CLAWTROL_TELEGRAM_BOT_TOKEN" => "test-token",
          "CLAWTROL_TELEGRAM_ALERT_CHAT_ID" => "123"
        }[k]
      }) do
        called = false
        Net::HTTP.stub(:post_form, ->(_uri, _params) { called = true }) do
          events = CatastrophicGuardrailsService.new.check!
          assert events.any? { |e| e[:kind] == "tasks_dropped" }
          assert called, "Expected Telegram to be attempted"
        end
      end
    end

    assert Notification.where(user: user, event_type: "catastrophic_guardrail").exists?
  end

  test "fail_fast raises" do
    User.delete_all

    assert_raises(CatastrophicGuardrailsService::CatastrophicDataLossError) do
      CatastrophicGuardrailsService.new(mode: "fail_fast").check!
    end
  end
end
