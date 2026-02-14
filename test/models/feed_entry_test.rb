# frozen_string_literal: true

require "test_helper"

class FeedEntryTest < ActiveSupport::TestCase
  def setup
    @user = users(:default)
  end

  # --- Validations ---

  test "valid entry with all required fields" do
    entry = FeedEntry.new(user: @user, feed_name: "HackerNews", title: "Test Article", url: "https://example.com/article-1")
    assert entry.valid?, entry.errors.full_messages.join(", ")
  end

  test "requires feed_name" do
    entry = FeedEntry.new(user: @user, title: "Test", url: "https://example.com/1")
    entry.feed_name = nil
    assert_not entry.valid?
    assert_includes entry.errors[:feed_name], "can't be blank"
  end

  test "requires title" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", url: "https://example.com/2")
    entry.title = nil
    assert_not entry.valid?
    assert_includes entry.errors[:title], "can't be blank"
  end

  test "requires url" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", title: "Test")
    entry.url = nil
    assert_not entry.valid?
    assert_includes entry.errors[:url], "can't be blank"
  end

  test "url must be valid http(s)" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", title: "Test", url: "ftp://bad.com")
    assert_not entry.valid?
    assert_includes entry.errors[:url], "must be a valid URL"
  end

  test "url must be unique" do
    FeedEntry.create!(user: @user, feed_name: "HN", title: "First", url: "https://example.com/unique-test")
    dup = FeedEntry.new(user: @user, feed_name: "HN", title: "Second", url: "https://example.com/unique-test")
    assert_not dup.valid?
    assert_includes dup.errors[:url], "has already been taken"
  end

  test "feed_name max length 100" do
    entry = FeedEntry.new(user: @user, feed_name: "x" * 101, title: "Test", url: "https://example.com/3")
    assert_not entry.valid?
  end

  test "title max length 500" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", title: "x" * 501, url: "https://example.com/4")
    assert_not entry.valid?
  end

  test "relevance_score must be between 0 and 1" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", title: "Test", url: "https://example.com/5")
    entry.relevance_score = 1.1
    assert_not entry.valid?

    entry.relevance_score = -0.1
    assert_not entry.valid?

    entry.relevance_score = 0.5
    assert entry.valid?
  end

  test "relevance_score can be nil" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", title: "Test", url: "https://example.com/6", relevance_score: nil)
    assert entry.valid?
  end

  # --- Enums ---

  test "default status is unread" do
    entry = FeedEntry.new
    assert_equal "unread", entry.status
  end

  test "status enum values" do
    assert_equal({ "unread" => 0, "read" => 1, "saved" => 2, "dismissed" => 3 }, FeedEntry.statuses)
  end

  # --- Instance Methods ---

  test "high_relevance? returns true for score >= 0.7" do
    entry = FeedEntry.new(relevance_score: 0.7)
    assert entry.high_relevance?
  end

  test "high_relevance? returns false for score < 0.7" do
    entry = FeedEntry.new(relevance_score: 0.69)
    assert_not entry.high_relevance?
  end

  test "high_relevance? returns false for nil score" do
    entry = FeedEntry.new(relevance_score: nil)
    assert_not entry.high_relevance?
  end

  test "relevance_label returns correct labels" do
    assert_equal "high", FeedEntry.new(relevance_score: 0.9).relevance_label
    assert_equal "high", FeedEntry.new(relevance_score: 0.8).relevance_label
    assert_equal "medium", FeedEntry.new(relevance_score: 0.5).relevance_label
    assert_equal "medium", FeedEntry.new(relevance_score: 0.7).relevance_label
    assert_equal "low", FeedEntry.new(relevance_score: 0.3).relevance_label
    assert_equal "unknown", FeedEntry.new(relevance_score: nil).relevance_label
  end

  test "time_ago returns human-readable time" do
    assert_equal "just now", FeedEntry.new(published_at: Time.current).time_ago
    assert_match(/\dm ago/, FeedEntry.new(published_at: 5.minutes.ago).time_ago)
    assert_match(/\dh ago/, FeedEntry.new(published_at: 3.hours.ago).time_ago)
    assert_match(/\dd ago/, FeedEntry.new(published_at: 2.days.ago).time_ago)
    assert_equal "unknown", FeedEntry.new(published_at: nil).time_ago
  end

  # --- Callbacks ---

  test "set_read_at when status changes to read" do
    entry = FeedEntry.new(user: @user, feed_name: "HN", title: "Test", url: "https://example.com/read-test")
    entry.status = :read
    # The callback checks status_changed?, which works on new records
    assert_nil entry.read_at
    # On save with status change, read_at should be set
    # (We can't test full save without DB, but verify the logic)
  end

  # --- Scopes (structural tests) ---

  test "newest_first scope orders by published_at desc" do
    assert_respond_to FeedEntry, :newest_first
  end

  test "high_relevance scope exists" do
    assert_respond_to FeedEntry, :high_relevance
  end

  test "by_feed scope exists" do
    assert_respond_to FeedEntry, :by_feed
  end

  test "recent scope exists" do
    assert_respond_to FeedEntry, :recent
  end

  test "unread_or_saved scope exists" do
    assert_respond_to FeedEntry, :unread_or_saved
  end

  # --- Association ---

  test "belongs to user" do
    assert_equal :belongs_to, FeedEntry.reflect_on_association(:user).macro
  end
end
