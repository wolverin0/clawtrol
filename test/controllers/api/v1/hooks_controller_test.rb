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
end
