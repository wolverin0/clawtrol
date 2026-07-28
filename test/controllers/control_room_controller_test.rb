# frozen_string_literal: true

require "test_helper"

class ControlRoomControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @source = @user.orchestration_sources.create!(
      profile: "primary",
      status: "healthy",
      last_seen_at: Time.current
    )
  end

  test "requires authentication" do
    get control_room_path
    assert_response :redirect
  end

  test "creates task and question intents" do
    sign_in_as(@user)

    post control_room_tasks_path, params: {
      source_id: @source.id,
      project: "whatsappbot",
      title: "Ship focused fix",
      brief: "Make the requested change",
      acceptance: "Tests and live smoke pass",
      priority: "high"
    }
    assert_redirected_to control_room_path(source_id: @source.id)

    task_intent = @user.orchestration_intents.last
    assert_equal "create_task", task_intent.kind
    assert_equal "task", task_intent.payload["kind"]

    post control_room_ask_path, params: {
      source_id: @source.id,
      project: "wezbridge",
      brief: "What should we improve next?"
    }
    assert_equal "question", @user.orchestration_intents.last.payload["kind"]
  end

  test "records operator message before bridge delivery" do
    task = projected_task
    sign_in_as(@user)

    post control_room_task_messages_path(task), params: { content: "Please explain the blocker." }
    assert_redirected_to control_room_path(task_id: task.id)

    intent = @user.orchestration_intents.find_by!(kind: "message")
    message = task.agent_messages.find_by!(direction: "outgoing")
    assert_equal "Please explain the blocker.", intent.payload["content"]
    assert_equal "T-0001", intent.payload["task_id"]
    assert_equal "operator", message.metadata["provenance"]
    assert_equal "clawtrol-intent:#{intent.id}", message.metadata["external_id"]
  end

  test "renders fleet sections and rejects another user's task" do
    task = projected_task
    @source.update!(panes: [
      { "pane_id" => 0, "project" => "wezbridge", "status" => "idle" },
      { "pane_id" => 5, "project" => "whatsappbot", "status" => "working" }
    ])
    sign_in_as(@user)

    get control_room_path(task_id: task.id)
    assert_response :success
    assert_select "h1", "Control Room"
    assert_select "main#main-content.w-full.max-w-none"
    assert_select "select[name='project']", count: 2
    assert_select "option[value='whatsappbot']", text: /pane 5/, count: 2
    assert_includes response.body, "Projected task"

    other = Task.create!(user: users(:two), board: boards(:two), name: "Other",
      origin_session_key: "wezbridge:primary:task:T-OTHER")
    post control_room_task_messages_path(other), params: { content: "No access" }
    assert_response :not_found
  end

  private

  def projected_task
    @user.tasks.create!(
      board: boards(:one),
      name: "Projected task",
      description: "Immutable brief",
      origin_session_id: "T-0001",
      origin_session_key: "wezbridge:primary:task:T-0001",
      status: :up_next,
      blocked: true,
      state_data: {
        "orchestration" => {
          "profile" => "primary",
          "source_state" => "blocked",
          "project" => "whatsappbot"
        }
      }
    )
  end
end
