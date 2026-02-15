# frozen_string_literal: true

require "test_helper"

class SessionResolverServiceTest < ActiveSupport::TestCase
  test "resolve_from_key returns nil for blank session_key" do
    assert_nil SessionResolverService.resolve_from_key("", task_id: 1)
    assert_nil SessionResolverService.resolve_from_key(nil, task_id: 1)
  end

  test "resolve_from_key returns nil for blank task_id" do
    assert_nil SessionResolverService.resolve_from_key("abc-123", task_id: nil)
    assert_nil SessionResolverService.resolve_from_key("abc-123", task_id: "")
  end

  test "resolve_from_key returns nil when sessions directory does not exist" do
    # TranscriptParser::SESSIONS_DIR likely doesn't exist in test env
    # so this should return nil naturally
    result = SessionResolverService.resolve_from_key("abc-123", task_id: 42)
    assert_nil result
  end

  test "scan_for_task returns nil for blank task_id" do
    assert_nil SessionResolverService.scan_for_task(nil)
    assert_nil SessionResolverService.scan_for_task("")
  end

  test "scan_for_task returns nil when sessions directory does not exist" do
    result = SessionResolverService.scan_for_task(42)
    assert_nil result
  end

  test "constants are defined" do
    assert_equal 7.days, SessionResolverService::SEARCH_LOOKBACK
    assert_equal 30, SessionResolverService::RECENT_FILE_LIMIT
    assert_equal 5_000, SessionResolverService::SAMPLE_READ_SIZE
  end
end
