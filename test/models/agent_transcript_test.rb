# frozen_string_literal: true

require "test_helper"

class AgentTranscriptTest < ActiveSupport::TestCase
  def setup
    @task = tasks(:one)
    @transcript = AgentTranscript.new(
      session_id: "sess_new_test",
      status: "parsed",
      model: "opus",
      prompt_text: "Do something",
      output_text: "Done!",
      total_tokens: 1000,
      input_tokens: 600,
      output_tokens: 400,
      message_count: 5,
      tool_call_count: 2,
      runtime_seconds: 30,
      task: @task
    )
  end

  # --- Validations ---

  test "valid transcript saves" do
    assert @transcript.valid?
  end

  test "requires session_id" do
    @transcript.session_id = nil
    assert_not @transcript.valid?
    assert_includes @transcript.errors[:session_id], "can't be blank"
  end

  test "session_id must be unique" do
    @transcript.save!
    dup = AgentTranscript.new(session_id: "sess_new_test", status: "captured")
    assert_not dup.valid?
    assert_includes dup.errors[:session_id].join, "already been taken"
  end

  test "session_id cannot exceed 255 characters" do
    @transcript.session_id = "a" * 256
    assert_not @transcript.valid?
  end

  test "session_key can be nil" do
    @transcript.session_key = nil
    assert @transcript.valid?
  end

  test "session_key cannot exceed 255 characters" do
    @transcript.session_key = "a" * 256
    assert_not @transcript.valid?
  end

  test "model can be nil" do
    @transcript.model = nil
    assert @transcript.valid?
  end

  test "model cannot exceed 100 characters" do
    @transcript.model = "a" * 101
    assert_not @transcript.valid?
  end

  test "status must be valid" do
    @transcript.status = "invalid"
    assert_not @transcript.valid?
  end

  test "all valid statuses accepted" do
    %w[captured parsed failed].each do |s|
      @transcript.status = s
      assert @transcript.valid?, "Status '#{s}' should be valid"
    end
  end

  # --- Associations ---

  test "task is optional" do
    @transcript.task = nil
    assert @transcript.valid?
  end

  test "task_run is optional" do
    @transcript.task_run = nil
    assert @transcript.valid?
  end

  # --- Scopes ---

  test "recent scope orders by created_at desc" do
    transcripts = AgentTranscript.recent
    assert transcripts.first.created_at >= transcripts.last.created_at if transcripts.size > 1
  end

  test "for_task filters by task_id" do
    task_transcripts = AgentTranscript.for_task(@task.id)
    assert task_transcripts.all? { |t| t.task_id == @task.id }
  end

  test "with_prompt returns only transcripts with prompt" do
    with_prompt = AgentTranscript.with_prompt
    assert with_prompt.all? { |t| t.prompt_text.present? }
    assert_includes with_prompt, agent_transcripts(:parsed)
    assert_not_includes with_prompt, agent_transcripts(:failed)
  end

  test "for_task returns empty for non-existent task" do
    result = AgentTranscript.for_task(999999)
    assert_equal [], result.to_a
  end

  test "strict_loading_mode is set" do
    transcript = AgentTranscript.new
    assert_includes [ :n_plus_one, :all ], transcript.class.strict_loading_mode
  end

  # --- capture_from_jsonl! ---

  test "capture_from_jsonl parses valid JSONL" do
    jsonl = <<~JSONL
      {"type":"message","timestamp":"2026-02-15T10:00:00Z","message":{"role":"user","content":"Hello"}}
      {"type":"message","timestamp":"2026-02-15T10:00:05Z","message":{"role":"assistant","content":"Hi there","model":"opus","usage":{"input_tokens":10,"output_tokens":5}}}
    JSONL

    tmpfile = Tempfile.new(["test", ".jsonl"])
    tmpfile.write(jsonl)
    tmpfile.close

    transcript = AgentTranscript.capture_from_jsonl!(tmpfile.path, task: @task, session_id: "sess_jsonl_test")

    assert transcript.persisted?
    assert_equal "parsed", transcript.status
    assert_equal "Hello", transcript.prompt_text
    assert_equal "Hi there", transcript.output_text
    assert_equal "opus", transcript.model
    assert_equal 10, transcript.input_tokens
    assert_equal 5, transcript.output_tokens
    assert_equal 2, transcript.message_count
  ensure
    tmpfile&.unlink
  end

  test "capture_from_jsonl skips if session already captured" do
    existing = agent_transcripts(:parsed)
    result = AgentTranscript.capture_from_jsonl!("/dev/null", session_id: existing.session_id)
    assert_equal existing, result
  end

  test "capture_from_jsonl creates failed record on error" do
    transcript = AgentTranscript.capture_from_jsonl!("/nonexistent/path.jsonl", session_id: "sess_fail_test")
    assert transcript.persisted?
    assert_equal "failed", transcript.status
    assert transcript.metadata["error"].present?
  end

  # --- Fixture smoke ---

  test "fixtures load correctly" do
    assert_equal "parsed", agent_transcripts(:parsed).status
    assert_equal "failed", agent_transcripts(:failed).status
    assert_equal 5000, agent_transcripts(:parsed).total_tokens
  end
end
