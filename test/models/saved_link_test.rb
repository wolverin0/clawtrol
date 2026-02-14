require "test_helper"

class SavedLinkTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
  end

  # --- Validations ---

  test "valid saved link" do
    link = SavedLink.new(user: @user, url: "https://example.com/article")
    assert link.valid?, "Expected valid: #{link.errors.full_messages}"
  end

  test "url is required" do
    link = SavedLink.new(user: @user, url: nil)
    assert_not link.valid?
    assert link.errors[:url].any?
  end

  test "url must be valid format" do
    link = SavedLink.new(user: @user, url: "not-a-url")
    assert_not link.valid?
    assert_includes link.errors[:url].join, "must be a valid URL"
  end

  test "rejects ftp urls" do
    link = SavedLink.new(user: @user, url: "ftp://files.example.com/doc.pdf")
    assert_not link.valid?
  end

  test "accepts https urls" do
    link = SavedLink.new(user: @user, url: "https://example.com")
    assert link.valid?
  end

  test "accepts http urls" do
    link = SavedLink.new(user: @user, url: "http://example.com")
    assert link.valid?
  end

  # --- Enum ---

  test "default status is pending" do
    link = SavedLink.new(user: @user, url: "https://example.com")
    assert_equal "pending", link.status
  end

  test "status enum values" do
    assert_equal({ "pending" => 0, "processing" => 1, "done" => 2, "failed" => 3 }, SavedLink.statuses)
  end

  # --- Source type detection ---

  test "detects youtube source type" do
    link = SavedLink.new(user: @user, url: "https://www.youtube.com/watch?v=abc123")
    link.valid?
    assert_equal "youtube", link.source_type
  end

  test "detects youtu.be short url" do
    link = SavedLink.new(user: @user, url: "https://youtu.be/abc123")
    link.valid?
    assert_equal "youtube", link.source_type
  end

  test "detects x.com source type" do
    link = SavedLink.new(user: @user, url: "https://x.com/user/status/12345")
    link.valid?
    assert_equal "x", link.source_type
  end

  test "detects twitter.com source type" do
    link = SavedLink.new(user: @user, url: "https://twitter.com/user/status/12345")
    link.valid?
    assert_equal "x", link.source_type
  end

  test "detects reddit source type" do
    link = SavedLink.new(user: @user, url: "https://www.reddit.com/r/rails/comments/abc")
    link.valid?
    assert_equal "reddit", link.source_type
  end

  test "defaults to article for unknown domains" do
    link = SavedLink.new(user: @user, url: "https://blog.example.com/post")
    link.valid?
    assert_equal "article", link.source_type
  end

  test "does not override manually set source_type" do
    link = SavedLink.new(user: @user, url: "https://youtube.com/watch", source_type: "custom")
    link.valid?
    assert_equal "custom", link.source_type
  end

  # --- Scopes ---

  test "newest_first orders by created_at desc" do
    old = SavedLink.create!(user: @user, url: "https://old.example.com", created_at: 1.day.ago)
    new_link = SavedLink.create!(user: @user, url: "https://new.example.com", created_at: Time.current)
    assert_equal new_link, SavedLink.newest_first.first
  end

  test "unprocessed returns pending and processing" do
    pending_link = SavedLink.create!(user: @user, url: "https://pending.example.com", status: :pending)
    processing_link = SavedLink.create!(user: @user, url: "https://processing.example.com", status: :processing)
    done_link = SavedLink.create!(user: @user, url: "https://done.example.com", status: :done)

    unprocessed = SavedLink.unprocessed
    assert_includes unprocessed, pending_link
    assert_includes unprocessed, processing_link
    assert_not_includes unprocessed, done_link
  end
end
