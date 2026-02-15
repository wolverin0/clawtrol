# frozen_string_literal: true

require "test_helper"

class TranscriptParserTest < ActiveSupport::TestCase
  # --- Session ID Validation ---

  test "transcript_path returns nil for blank session_id" do
    assert_nil TranscriptParser.transcript_path("")
    assert_nil TranscriptParser.transcript_path(nil)
  end

  test "transcript_path rejects path traversal in session_id" do
    assert_nil TranscriptParser.transcript_path("../../etc/passwd")
    assert_nil TranscriptParser.transcript_path("../secret")
    assert_nil TranscriptParser.transcript_path("foo/bar")
  end

  test "transcript_path rejects session_id with special chars" do
    assert_nil TranscriptParser.transcript_path("session;rm -rf /")
    assert_nil TranscriptParser.transcript_path("session\x00null")
    assert_nil TranscriptParser.transcript_path("session with spaces")
  end

  test "VALID_SESSION_ID allows alphanumeric and hyphens" do
    assert_match TranscriptParser::VALID_SESSION_ID, "abc-123_DEF"
    assert_match TranscriptParser::VALID_SESSION_ID, "a1b2c3"
    refute_match TranscriptParser::VALID_SESSION_ID, "has spaces"
    refute_match TranscriptParser::VALID_SESSION_ID, "../traversal"
  end

  # --- Line Parsing ---

  test "parse_line returns nil for blank line" do
    assert_nil TranscriptParser.parse_line("")
    assert_nil TranscriptParser.parse_line(nil)
  end

  test "parse_line returns nil for invalid JSON" do
    assert_nil TranscriptParser.parse_line("not valid json")
  end

  test "parse_line returns nil for non-message type" do
    line = '{"type": "system", "data": "something"}'
    assert_nil TranscriptParser.parse_line(line)
  end

  test "parse_line parses assistant message with text content" do
    line = {
      type: "message",
      message: {
        role: "assistant",
        content: [{ type: "text", text: "Hello, world!" }]
      },
      timestamp: Time.current.iso8601
    }.to_json

    result = TranscriptParser.parse_line(line, 1)
    assert_not_nil result
    assert_equal "assistant", result[:role]
    assert_equal 1, result[:line]
    text_content = result[:content].find { |c| c[:type] == "text" }
    assert_equal "Hello, world!", text_content[:text]
  end

  test "parse_line parses user message" do
    line = {
      type: "message",
      message: {
        role: "user",
        content: "What is 2+2?"
      },
      timestamp: Time.current.iso8601
    }.to_json

    result = TranscriptParser.parse_line(line, 5)
    assert_not_nil result
    assert_equal "user", result[:role]
    assert_equal 5, result[:line]
  end

  # --- parse_json ---

  test "parse_json handles valid JSON" do
    result = TranscriptParser.parse_json('{"key": "value"}')
    assert_equal({ "key" => "value" }, result)
  end

  test "parse_json returns nil for invalid JSON" do
    assert_nil TranscriptParser.parse_json("not json")
    assert_nil TranscriptParser.parse_json("")
  end

  # --- each_entry ---

  test "each_entry yields parsed entries from file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.jsonl")
      File.write(path, [
        { type: "message", role: "user", content: "hello" }.to_json,
        { type: "message", role: "assistant", content: [{ type: "text", text: "hi" }] }.to_json
      ].join("\n"))

      entries = []
      TranscriptParser.each_entry(path) { |data, num| entries << [data, num] }
      assert_equal 2, entries.length
      assert_equal "user", entries[0][0]["role"]
      assert_equal 1, entries[0][1]
      assert_equal "assistant", entries[1][0]["role"]
      assert_equal 2, entries[1][1]
    end
  end

  test "each_entry skips blank and invalid lines" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.jsonl")
      File.write(path, "\n\nnot json\n{\"type\":\"message\",\"role\":\"user\",\"content\":\"ok\"}\n")

      entries = []
      TranscriptParser.each_entry(path) { |data, _| entries << data }
      assert_equal 1, entries.length
    end
  end

  # --- flatten_content_text ---

  test "flatten_content_text handles string content" do
    assert_equal "hello", TranscriptParser.flatten_content_text("hello")
  end

  test "flatten_content_text handles array content with text blocks" do
    content = [
      { "type" => "text", "text" => "part 1" },
      { "type" => "text", "text" => "part 2" }
    ]
    result = TranscriptParser.flatten_content_text(content)
    assert_includes result, "part 1"
    assert_includes result, "part 2"
  end

  test "flatten_content_text handles nil" do
    assert_equal "", TranscriptParser.flatten_content_text(nil)
  end

  # --- extract_output_files ---

  test "extract_output_files finds file paths in transcript" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.jsonl")
      File.write(path, {
        type: "message",
        role: "assistant",
        content: [{ type: "text", text: "Created file: app/models/user.rb\nAlso modified test/models/user_test.rb" }]
      }.to_json)

      files = TranscriptParser.extract_output_files(path)
      assert_kind_of Array, files
    end
  end

  # --- sessions_dir ---

  test "sessions_dir returns expected path" do
    assert_match(/\.openclaw\/agents\/main\/sessions/, TranscriptParser.sessions_dir)
  end
end
