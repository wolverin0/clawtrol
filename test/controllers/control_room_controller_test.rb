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
      brief: "What should we improve next?"
    }
    question_intent = @user.orchestration_intents.last
    assert_equal "question", question_intent.payload["kind"]
    assert_equal "_fleet", question_intent.payload["project"]
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
    assert_select "[data-controller='control-room-live']", count: 1
    assert_select "[data-control-room-live-region='requests']", count: 1
    assert_select "h2", "Recent requests"
    assert_select "[data-controller='gateway-health']", count: 0
    assert_select "select#task_project", count: 1
    assert_select "select#question_project", count: 1
    assert_select "select#question_project" do |select|
      assert_equal "_fleet", select.first.css("option").first["value"]
    end
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

  test "renders live cockpit regions with durable request outcomes" do
    task = projected_task
    applied = @user.orchestration_intents.create!(
      orchestration_source: @source,
      task:,
      kind: "message",
      status: "applied",
      processed_at: Time.current,
      result: { "message" => "Delivered to the ledger" }
    )
    @user.orchestration_intents.create!(
      orchestration_source: @source,
      task:,
      kind: "cancel",
      status: "rejected",
      processed_at: Time.current,
      result: { "reason" => "Task is already complete" }
    )
    sign_in_as(@user)

    get control_room_live_path(source_id: @source.id)

    assert_response :success
    assert_select "[data-control-room-live-region]", count: 5
    assert_select "[data-control-room-live-region='requests']", text: /##{applied.id} Message/
    assert_includes response.body, "Delivered to the ledger"
    assert_includes response.body, "Task is already complete"
  end

  test "needs attention is a truthful union and explains gated work" do
    blocked = projected_task
    blocked.update!(
      name: "T-0022 judicial balance ruling",
      state_data: blocked.state_data.deep_merge(
        "orchestration" => {
          "blocker" => "Operator must decide whether to dispose ARS 8,025,812.27.",
          "next_action" => "Answer with approve or retain.",
          "acceptance" => ["Decision is recorded"],
          "evidence" => ["20 balances affect current members"],
          "contract" => { "mode" => "born_blocked", "gate" => "operator" }
        }
      )
    )
    decision = projected_task_with(
      id: "T-0023",
      name: "T-0023 rotate exposed credential",
      state: "queued",
      needs_decision: true
    )
    question = projected_task_with(
      id: "T-0024",
      name: "Open operator question",
      state: "queued",
      kind: "question"
    )
    projected_task_with(id: "T-0025", name: "Completed question", state: "done", kind: "question", status: :done)
    projected_task_with(id: "T-0026", name: "Normal active task", state: "running")
    sign_in_as(@user)

    get control_room_path(task_id: blocked.id)

    assert_response :success
    attention = css_select("[data-board-section='needs-attention']").sole
    assert_equal "3", attention["data-source-count"]
    assert_equal "3", attention["data-rendered-count"]
    assert_equal 1, attention.css("[data-task-origin-id='#{blocked.origin_session_id}']").count
    assert_equal 1, attention.css("[data-task-origin-id='#{decision.origin_session_id}']").count
    assert_equal 1, attention.css("[data-task-origin-id='#{question.origin_session_id}']").count
    assert_equal 0, attention.css("[data-task-origin-id='T-0025']").count
    assert_includes attention.text, "Blocked by"
    assert_includes attention.text, "ARS 8,025,812.27"
    assert_includes attention.text, "Gate"
    assert_includes attention.text, "operator"
    assert_includes attention.text, "Next action"
    assert_includes attention.text, "Acceptance"
    assert_includes attention.text, "Evidence"
    blocked_card = attention.css("[data-task-origin-id='#{blocked.origin_session_id}']").sole
    assert_includes blocked_card.text, "1 criterion"
    assert_includes blocked_card.text, "1 evidence item"
    assert_not_includes blocked_card.text, "Decision is recorded"
    assert_not_includes blocked_card.text, "20 balances affect current members"
    assert_equal 3, blocked_card.css("[data-task-context='compact'] .line-clamp-2").count

    full_context = css_select("#task-thread [data-task-context='full']").sole
    assert_includes full_context.text, "Decision is recorded"
    assert_includes full_context.text, "20 balances affect current members"
    assert_select "#task-thread form[action='#{control_room_task_messages_path(blocked)}']", count: 1
  end

  test "renders a loud stalled bridge warning with its error" do
    @source.update!(
      last_seen_at: 5.minutes.ago,
      last_error: "sync HTTP 503",
      health: { "stalled" => true, "stale_seconds" => 305 }
    )
    sign_in_as(@user)

    get control_room_path

    assert_response :success
    assert_select "[data-control-room-live-region='source-health'][role='alert']", count: 1 do
      assert_select "h2", "Orchestration bridge is stalled"
      assert_select "p", text: /board may be showing old state/i
      assert_select "p", text: /sync HTTP 503/
    end
    assert_select "[data-control-room-live-region='source-badges']", text: /attention/
  end

  test "live cockpit requires authentication" do
    get control_room_live_path
    assert_response :redirect
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
    assert_select "time[datetime][title]", text: /ago/
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

  def projected_task_with(id:, name:, state:, kind: "task", status: :up_next, needs_decision: false)
    @user.tasks.create!(
      board: boards(:one),
      name:,
      description: "Immutable brief",
      origin_session_id: id,
      origin_session_key: "wezbridge:primary:task:#{id}",
      status:,
      needs_decision:,
      state_data: {
        "orchestration" => {
          "profile" => "primary",
          "source_state" => state,
          "project" => "whatsappbot",
          "kind" => kind
        }
      }
    )
  end
end
