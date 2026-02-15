# frozen_string_literal: true

require "test_helper"
require "fileutils"

class Api::V1::HooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @task = tasks(:one)
    @token = Rails.application.config.hooks_token
  end

  test "agent_complete returns unauthorized with bad token" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "nope" },
         headers: { "X-Hook-Token" => "wrong" }

    assert_response :unauthorized
  end

  test "agent_complete updates task and prepends agent activity + output (and persists transcript file)" do
    @task.update!(description: "Original description")

    # Create a fake OpenClaw transcript
    session_id = "sess-123"
    transcript_path = File.expand_path("~/.openclaw/agents/main/sessions/#{session_id}.jsonl")
    FileUtils.mkdir_p(File.dirname(transcript_path))
    File.write(transcript_path, "{\"type\":\"message\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"hello\"}]}}\n")

    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "Hook findings", session_id: session_id },
         headers: { "X-Hook-Token" => @token }

    assert_response :success

    @task.reload
    assert_equal "in_review", @task.status
    assert_equal session_id, @task.agent_session_id

    assert_match(/\A## Agent Activity\n/m, @task.description)
    assert_match(/## Agent Output\n\nHook findings/m, @task.description)
    assert_match(/\n\n---\n\nOriginal description\z/m, @task.description)

    # Transcript copy saved and added to output_files
    expected_rel = "storage/agent_activity/task-#{@task.id}-session-#{session_id}.jsonl"
    assert_includes @task.output_files, expected_rel
    assert File.exist?(Rails.root.join(expected_rel)), "expected persisted transcript to exist"
  ensure
    File.delete(transcript_path) if transcript_path && File.exist?(transcript_path)
  end

  test "agent_complete replaces existing top agent block on duplicate calls" do
    @task.update!(description: "## Agent Activity\n\nOld activity\n\n## Agent Output\n\nOld findings\n\n---\n\nOriginal description")

    post "/api/v1/hooks/agent_complete",
         params: { task_id: @task.id, findings: "New findings" },
         headers: { "X-Hook-Token" => @token }

    assert_response :success

    @task.reload
    assert_equal "in_review", @task.status
    assert_match(/\A## Agent Activity\n/m, @task.description)
    assert_match(/## Agent Output\n\nNew findings\n\n---\n\nOriginal description\z/m, @task.description)
  end

  # --- task_outcome tests ---

  test "task_outcome returns unauthorized with bad token" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "1", run_id: SecureRandom.uuid },
         headers: { "X-Hook-Token" => "wrong" }
    assert_response :unauthorized
  end

  test "task_outcome rejects invalid version" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "99", run_id: SecureRandom.uuid },
         headers: { "X-Hook-Token" => @token }
    assert_response :unprocessable_entity
  end

  test "task_outcome rejects invalid run_id" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: @task.id, version: "1", run_id: "not-a-uuid" },
         headers: { "X-Hook-Token" => @token }
    assert_response :unprocessable_entity
  end

  test "task_outcome creates task run and moves to in_review" do
    run_id = SecureRandom.uuid
    @task.update!(status: :in_progress)

    post "/api/v1/hooks/task_outcome",
         params: {
           task_id: @task.id, version: "1", run_id: run_id,
           summary: "All done", recommended_action: "in_review",
           achieved: ["thing1"], needs_follow_up: false
         },
         headers: { "X-Hook-Token" => @token }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "in_review", @task.reload.status
    assert_equal 1, @task.run_count
  end

  test "task_outcome is idempotent on duplicate run_id" do
    run_id = SecureRandom.uuid
    @task.update!(status: :in_progress)

    2.times do
      post "/api/v1/hooks/task_outcome",
           params: { task_id: @task.id, version: "1", run_id: run_id, summary: "Done",
                     recommended_action: "in_review", needs_follow_up: false },
           headers: { "X-Hook-Token" => @token },
           as: :json
      assert_response :success
    end

    assert_equal 1, TaskRun.where(run_id: run_id).count
  end

  test "task_outcome rejects requeue without next_prompt" do
    post "/api/v1/hooks/task_outcome",
         params: {
           task_id: @task.id, version: "1", run_id: SecureRandom.uuid,
           recommended_action: "requeue_same_task", needs_follow_up: true, next_prompt: ""
         },
         headers: { "X-Hook-Token" => @token }
    assert_response :unprocessable_entity
  end

  test "task_outcome returns not_found for missing task" do
    post "/api/v1/hooks/task_outcome",
         params: { task_id: 999999, version: "1", run_id: SecureRandom.uuid, recommended_action: "in_review", needs_follow_up: false },
         headers: { "X-Hook-Token" => @token }
    assert_response :not_found
  end

  test "agent_complete returns not_found for missing task" do
    post "/api/v1/hooks/agent_complete",
         params: { task_id: 999999, findings: "stuff" },
         headers: { "X-Hook-Token" => @token }
    assert_response :not_found
  end

  # --- Scoping: hooks find tasks by session_key ---

  test "agent_complete finds task by session_key" do
    @task.update!(agent_session_key: "unique-key-123", description: "Orig")

    post "/api/v1/hooks/agent_complete",
         params: { session_key: "unique-key-123", findings: "Found by key" },
         headers: { "X-Hook-Token" => @token }

    assert_response :success
    assert_match "Found by key", @task.reload.description
  end
end
