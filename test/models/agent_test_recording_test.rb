# frozen_string_literal: true

require "test_helper"

class AgentTestRecordingTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @task = tasks(:one)
    @recording = AgentTestRecording.new(
      name: "Login test",
      status: "recorded",
      session_id: "sess_123",
      action_count: 3,
      actions: [{ "type" => "click", "target" => "#btn" }],
      assertions: [{ "type" => "visible", "selector" => "#result" }],
      metadata: {},
      user: @user,
      task: @task
    )
  end

  # --- Validations ---

  test "valid recording saves" do
    assert @recording.valid?
  end

  test "requires name" do
    @recording.name = nil
    assert_not @recording.valid?
    assert_includes @recording.errors[:name], "can't be blank"
  end

  test "name cannot exceed 255 characters" do
    @recording.name = "a" * 256
    assert_not @recording.valid?
  end

  test "status must be in STATUSES" do
    @recording.status = "invalid"
    assert_not @recording.valid?
  end

  test "all valid statuses accepted" do
    AgentTestRecording::STATUSES.each do |s|
      @recording.status = s
      assert @recording.valid?, "Status '#{s}' should be valid"
    end
  end

  test "session_id cannot exceed 100 characters" do
    @recording.session_id = "a" * 101
    assert_not @recording.valid?
  end

  test "session_id allows nil" do
    @recording.session_id = nil
    assert @recording.valid?
  end

  test "action_count must be non-negative integer" do
    @recording.action_count = -1
    assert_not @recording.valid?

    @recording.action_count = 0
    assert @recording.valid?
  end

  # --- Associations ---

  test "belongs_to user" do
    assert_equal @user, @recording.user
  end

  test "task is optional" do
    @recording.task = nil
    assert @recording.valid?
  end

  # --- Scopes ---

  test "recent scope orders by created_at desc" do
    @recording.save!
    recordings = AgentTestRecording.recent
    assert recordings.first.created_at >= recordings.last.created_at
  end

  test "by_status filters correctly" do
    assert_includes AgentTestRecording.by_status("recorded"), agent_test_recordings(:recorded)
    assert_not_includes AgentTestRecording.by_status("verified"), agent_test_recordings(:recorded)
  end

  test "verified scope returns only verified" do
    verified = AgentTestRecording.verified
    assert_includes verified, agent_test_recordings(:verified)
    assert_not_includes verified, agent_test_recordings(:recorded)
  end

  test "for_task scope filters by task" do
    task_recordings = AgentTestRecording.for_task(@task.id)
    assert task_recordings.all? { |r| r.task_id == @task.id }
  end

  # --- Fixture smoke test ---

  test "fixtures load correctly" do
    assert_equal "recorded", agent_test_recordings(:recorded).status
    assert_equal "verified", agent_test_recordings(:verified).status
    assert agent_test_recordings(:verified).verified_at.present?
  end

  # --- JSON fields ---
  test "actions can store valid JSON array" do
    @recording.actions = [{ "type" => "click", "target" => "#btn" }]
    assert @recording.valid?
    assert_equal 1, @recording.actions.size
  end

  test "actions can be nil" do
    @recording.actions = nil
    assert @recording.valid?
  end

  test "assertions can store valid JSON array" do
    @recording.assertions = [{ "type" => "visible", "selector" => "#result" }]
    assert @recording.valid?
  end

  test "assertions can be nil" do
    @recording.assertions = nil
    assert @recording.valid?
  end

  test "metadata can store valid JSON object" do
    @recording.metadata = { "browser" => "chrome" }
    assert @recording.valid?
  end

  test "metadata can be nil" do
    @recording.metadata = nil
    assert @recording.valid?
  end

  # --- Edge cases ---
  test "action_count can be zero" do
    @recording.action_count = 0
    assert @recording.valid?
  end

  test "action_count accepts large values" do
    @recording.action_count = 999_999
    assert @recording.valid?
  end

  test "session_id can be empty string" do
    @recording.session_id = ""
    assert @recording.valid?
  end

  # --- Status transitions ---
  test "can create with verified status" do
    @recording.status = "verified"
    @recording.verified_at = Time.current
    assert @recording.valid?
  end

  test "verified_at can be nil for non-verified status" do
    @recording.status = "recorded"
    @recording.verified_at = nil
    assert @recording.valid?
  end

  test "pending status is valid" do
    @recording.status = "pending"
    assert @recording.valid?
  end

  test "failed status is valid" do
    @recording.status = "failed"
    assert @recording.valid?
  end

  # --- Additional scope tests ---
  test "for_task accepts task object" do
    @recording.save!
    results = AgentTestRecording.for_task(@task)
    assert_equal 1, results.count
    assert_equal @recording, results.first
  end

  test "by_status returns correct records" do
    recorded = AgentTestRecording.by_status("recorded")
    assert recorded.all? { |r| r.status == "recorded" }
  end
end
