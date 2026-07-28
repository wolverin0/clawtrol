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
    @source.update!(
      health: { "fleet" => { "a2a_envelopes" => 0 } },
      panes: [
        { "pane_id" => 0, "project" => "wezbridge", "status" => "idle" },
        { "pane_id" => 5, "project" => "whatsappbot", "status" => "working" },
        { "pane_id" => 9, "project" => "omniremote", "status" => "unknown" }
      ]
    )
    sign_in_as(@user)

    get control_room_path(task_id: task.id)
    assert_response :success
    assert_select "h1", "Control Room"
    assert_select "main#main-content.w-full.max-w-none"
    assert_select "[data-controller='gateway-health']", count: 0
    assert_select "select#task_project", count: 1
    assert_select "select#question_project", count: 1
    assert_select "option[value='whatsappbot']", text: /pane 5/, count: 2
    assert_select "option[value='omniremote']", text: /present/, count: 2
    assert_includes response.body, "No A2A updates in latest sync"
    assert_includes response.body, "Projected task"
    ids = css_select("[id]").map { |element| element["id"] }
    assert_equal ids.uniq, ids, "Control Room must not render duplicate HTML ids"

    other = Task.create!(user: users(:two), board: boards(:two), name: "Other",
      origin_session_key: "wezbridge:primary:task:T-OTHER")
    post control_room_task_messages_path(other), params: { content: "No access" }
    assert_response :not_found
  end

  test "renders an owned task thread fragment and hides another user's task" do
    task = projected_task
    task.agent_messages.create!(
      direction: "incoming",
      message_type: "output",
      content: "Fresh orchestrator reply",
      sender_name: "pane 0"
    )
    sign_in_as(@user)

    get control_room_task_thread_path(task)
    assert_response :success
    assert_select "#task-thread-messages[data-version]"
    assert_includes response.body, "Fresh orchestrator reply"

    other = Task.create!(user: users(:two), board: boards(:two), name: "Other",
      origin_session_key: "wezbridge:primary:task:T-OTHER")
    get control_room_task_thread_path(other)
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
