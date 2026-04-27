# frozen_string_literal: true

require "test_helper"

class DailyExecutiveDigestServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @board = boards(:one) || @user.boards.first
    @service = DailyExecutiveDigestService.new(@user)

    # Clean existing tasks
    @user.tasks.destroy_all

    # Save original ENV values
    @orig_clawtrol_bot = ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"]
    @orig_bot = ENV["TELEGRAM_BOT_TOKEN"]
    @orig_clawtrol_chat = ENV["CLAWTROL_TELEGRAM_CHAT_ID"]
    @orig_chat = ENV["TELEGRAM_CHAT_ID"]

    # Mock time
    travel_to Time.zone.local(2026, 2, 24, 12, 0, 0)
  end

  def teardown
    travel_back
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = @orig_clawtrol_bot
    ENV["TELEGRAM_BOT_TOKEN"] = @orig_bot
    ENV["CLAWTROL_TELEGRAM_CHAT_ID"] = @orig_clawtrol_chat
    ENV["TELEGRAM_CHAT_ID"] = @orig_chat
  end

  test "formats digest with empty state" do
    digest = @service.format_digest
    assert_includes digest, "📊 <b>Daily Executive Digest</b>"
    assert_includes digest, "• <i>No tasks completed</i>"
    assert_includes digest, "• <i>Inbox zero!</i>"
    assert_not_includes digest, "❌ <b>Failed Today"
    assert_not_includes digest, "🚧 <b>Blocked"
  end

  test "formats digest with tasks" do
    # Create done tasks today
    Task.create!(user: @user, board: @board, name: "Done 1", status: "done", updated_at: Time.current)
    Task.create!(user: @user, board: @board, name: "Done 2", status: "done", updated_at: Time.current)

    # Create done task yesterday (should not be included)
    Task.create!(user: @user, board: @board, name: "Done Yesterday", status: "done", updated_at: 1.day.ago)

    # Create failed task today
    Task.create!(user: @user, board: @board, name: "Failed 1", error_at: Time.current, updated_at: Time.current)

    # Create blocked task
    Task.create!(user: @user, board: @board, name: "Blocked 1", blocked: true, updated_at: 1.day.ago)

    # Create up_next tasks
    Task.create!(user: @user, board: @board, name: "Next 1", status: "up_next", priority: "high", position: 1)
    Task.create!(user: @user, board: @board, name: "Next 2", status: "up_next", priority: "medium", position: 2)

    digest = @service.format_digest

    assert_includes digest, "✅ <b>Done Today (2):</b>"
    assert_includes digest, "• Done 1"
    assert_includes digest, "• Done 2"
    assert_not_includes digest, "Done Yesterday"

    assert_includes digest, "❌ <b>Failed Today (1):</b>"
    assert_includes digest, "• Failed 1"

    assert_includes digest, "🚧 <b>Blocked (1):</b>"
    assert_includes digest, "• Blocked 1"

    assert_includes digest, "⏭️ <b>Up Next (Top 3):</b>"
    assert_includes digest, "• Next 1"
    assert_includes digest, "• Next 2"
  end

  test "truncates lists larger than 5" do
    6.times do |i|
      Task.create!(user: @user, board: @board, name: "Done #{i}", status: "done", updated_at: Time.current)
    end

    digest = @service.format_digest
    assert_includes digest, "✅ <b>Done Today (6):</b>"
    assert_includes digest, "• <i>...and 1 more</i>"
  end

  test "telegram_configured? checks environment and user settings" do
    # Neither configured
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = nil
    ENV["TELEGRAM_BOT_TOKEN"] = nil
    @user.update_column(:telegram_chat_id, nil)
    ENV["CLAWTROL_TELEGRAM_CHAT_ID"] = nil
    ENV["TELEGRAM_CHAT_ID"] = nil

    assert_not @service.send(:telegram_configured?)

    # Both configured
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "token"
    @user.update_column(:telegram_chat_id, "123")
    assert @service.send(:telegram_configured?)
  end

  test "sends telegram message via HTTP" do
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "fake-token"
    @user.update_column(:telegram_chat_id, "fake-chat-id")

    # Stub the HTTP request using Mocha (if available) or override
    # Since stubs failed earlier, we'll use Minitest's mock/stub or monkeypatch
    # In Rails 7, we can use webmock, but let's just monkeypatch Net::HTTP for this block
    mock_called = false
    Net::HTTP.stub :post_form, ->(uri, params) {
      assert_equal "https://api.telegram.org/botfake-token/sendMessage", uri.to_s
      assert_equal "fake-chat-id", params[:chat_id]
      assert_equal "HTML", params[:parse_mode]
      assert_match /Daily Executive Digest/, params[:text]
      mock_called = true
    } do
      @service.call
    end
    assert mock_called
  end

  test "rescues standard errors during telegram send" do
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "fake-token"
    @user.update_column(:telegram_chat_id, "fake-chat-id")

    # Raise error
    Net::HTTP.stub :post_form, ->(_, _) { raise StandardError, "Network error" } do
      Rails.logger.stub :warn, ->(msg) { assert_match /Network error/, msg } do
        assert_nothing_raised do
          @service.call
        end
      end
    end
  end
end
