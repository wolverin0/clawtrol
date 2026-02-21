# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class SessionResolverServiceTest < ActiveSupport::TestCase
  test "resolve_from_key returns nil for blank session_key" do
    assert_nil SessionResolverService.resolve_from_key("", task_id: 1)
    assert_nil SessionResolverService.resolve_from_key(nil, task_id: 1)
  end

  test "resolve_from_key returns nil for blank task_id" do
    assert_nil SessionResolverService.resolve_from_key("abc-123", task_id: nil)
    assert_nil SessionResolverService.resolve_from_key("abc-123", task_id: "")
  end

  test "resolve_from_key matches using session key marker and task marker" do
    Dir.mktmpdir do |dir|
      good_session_id = "good-session-1"
      bad_session_id = "bad-session-1"

      File.write(File.join(dir, "#{bad_session_id}.jsonl"), <<~JSONL)
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"Task #258 only"}]}}
      JSONL

      File.write(File.join(dir, "#{good_session_id}.jsonl"), <<~JSONL)
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"Your session: agent:main:subagent:abc-123\n## Task #258: Fix telemetry"}]}}
      JSONL

      TranscriptParser.stub(:sessions_dir, dir) do
        result = SessionResolverService.resolve_from_key("agent:main:subagent:abc-123", task_id: 258)
        assert_equal good_session_id, result
      end
    end
  end

  test "resolve_from_key ignores interactive telegram transcripts" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "chat-session.jsonl"), <<~JSONL)
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"requester channel: telegram\nTask #258\nagent:main:subagent:abc-123"}]}}
      JSONL

      TranscriptParser.stub(:sessions_dir, dir) do
        assert_nil SessionResolverService.resolve_from_key("agent:main:subagent:abc-123", task_id: 258)
      end
    end
  end

  test "scan_for_task returns nil for blank task_id" do
    assert_nil SessionResolverService.scan_for_task(nil)
    assert_nil SessionResolverService.scan_for_task("")
  end

  test "constants are defined" do
    assert_equal 7.days, SessionResolverService::SEARCH_LOOKBACK
    assert_equal 30, SessionResolverService::RECENT_FILE_LIMIT
    assert_equal 5_000, SessionResolverService::SAMPLE_READ_SIZE
  end
end
