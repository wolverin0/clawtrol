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
    assert_select "summary", text: /Delivery log/
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
    assert_select "[data-control-room-live-region='fleet'][data-source-count='3'][data-rendered-count='3']"
    assert_select "[data-pane-status='working']", count: 1
    assert_select "[data-pane-status='idle']", count: 1
    assert_select "[data-pane-status='present']", count: 1
    assert_select "aside#task-thread[role='complementary'][data-persistent-drawer='true']", count: 1
    assert_select "#task-thread[aria-modal]", count: 0
    assert_select "#task-thread a[href='#{board_task_path(task.board, task)}'][data-turbo-frame='task_panel']",
      text: "Open full task"
    assert_select "turbo-frame#task_panel", count: 1
    assert_select "#task-thread [data-task-context='full']", count: 0
    assert_select "#task-thread #task-thread-messages", count: 0
    projected_link = css_select("[data-task-origin-id='#{task.origin_session_id}']").sole
    assert_not_includes projected_link["href"], "#task-thread"
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
    assert_select "[data-control-room-live-region]", count: 4
    assert_select "[data-control-room-live-region='requests'][data-source-count='2'][data-rendered-count='2']",
      text: /##{applied.id} Message/
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
    attention = css_select("[data-board-section='waiting-on-you']").sole
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

    assert_select "#task-thread [data-task-context='full']", count: 0
    assert_select "#task-thread", text: /Operator must decide whether to dispose ARS 8,025,812\.27/
    assert_select "#task-thread", text: /Answer with approve or retain/
    assert_not_includes css_select("#task-thread").sole.text, "Decision is recorded"
    assert_not_includes css_select("#task-thread").sole.text, "20 balances affect current members"
    assert_select "#task-thread form[action='#{control_room_task_messages_path(blocked)}']", count: 1
  end

  test "splits open work into disjoint truthful lanes with operational project counts" do
    waiting = projected_task_with(id: "T-0101", name: "Needs a reply", state: "review")
    running = projected_task_with(id: "T-0102", name: "Executing now", state: "running")
    queued = projected_task_with(id: "T-0103", name: "Starts next", state: "ready")
    program = projected_task_with(
      id: "T-0104",
      name: "Long-running quality loop",
      state: "queued",
      kind: "bot-fix"
    )
    explicit_program = projected_task_with(
      id: "T-0105",
      name: "Explicit program",
      state: "running",
      kind: "task",
      work_type: "program",
      project: "mutual"
    )
    completed = projected_task_with(
      id: "T-0106",
      name: "Finished",
      state: "done",
      status: :done
    )
    unclassified = projected_task_with(
      id: "T-0107",
      name: "Unknown source state",
      state: "paused"
    )
    sign_in_as(@user)

    get control_room_path

    assert_response :success
    expected = {
      "waiting-on-you" => [waiting],
      "running-now" => [running],
      "queued-next" => [queued],
      "programs" => [program, explicit_program],
      "unclassified" => [unclassified],
      "recently-completed" => [completed]
    }
    rendered_ids = expected.flat_map do |section_name, tasks|
      section = css_select("[data-board-section='#{section_name}']").sole
      assert_equal tasks.length.to_s, section["data-source-count"], section_name
      assert_equal tasks.length.to_s, section["data-rendered-count"], section_name
      ids = section.css("[data-task-origin-id]").map { |card| card["data-task-origin-id"] }
      assert_equal tasks.map(&:origin_session_id).sort, ids.sort, section_name
      ids
    end
    assert_equal rendered_ids.uniq.sort, rendered_ids.sort, "a task must render in one lane only"

    board = css_select("[data-control-room-live-region='task-board']").sole
    assert_equal "6", board["data-open-source-count"]
    assert_equal "1", board["data-unclassified-count"]
    assert_includes css_select("[data-board-section='unclassified']").sole.text,
      "classification gap, not work you owe"
    summary = css_select("[data-board-section='project-work-summary']").sole
    assert_equal "2", summary["data-source-count"]
    assert_equal "2", summary["data-rendered-count"]
    assert_includes summary.text,
      "whatsappbot: 1 waiting · 1 running · 1 queued · 1 program · 1 unclassified"
    assert_includes summary.text, "mutual: 1 program"
    assert_includes summary.text, "1 unclassified"
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
      assert_select "span", text: /primary · attention/
      assert_select "p", text: /board may be showing old state/i
      assert_select "p", text: /sync HTTP 503/
    end
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

  def projected_task_with(
    id:, name:, state:, kind: "task", status: :up_next, needs_decision: false,
    project: "whatsappbot", work_type: nil
  )
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
          "project" => project,
          "kind" => kind,
          "work_type" => work_type
        }
      }
    )
  end
end
