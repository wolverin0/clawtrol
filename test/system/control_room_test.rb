# frozen_string_literal: true

require "application_system_test_case"

class ControlRoomTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @source = @user.orchestration_sources.create!(
      profile: "primary",
      status: "healthy",
      last_seen_at: Time.current,
      panes: [{ "pane_id" => 0, "project" => "wezbridge", "status" => "idle" }]
    )
    @task = @user.tasks.create!(
      board: boards(:one),
      name: "Review the canary",
      description: "Confirm the live evidence.",
      origin_session_id: "T-0001",
      origin_session_key: "wezbridge:primary:task:T-0001",
      status: :up_next,
      blocked: true,
      state_data: {
        "orchestration" => {
          "profile" => "primary",
          "source_state" => "blocked",
          "project" => "whatsappbot",
          "blocker" => "Operator ruling required before execution.",
          "next_action" => "Answer in this thread.",
          "acceptance" => ["Operator decision is recorded"],
          "evidence" => ["The contract was evaluated"],
          "contract" => { "mode" => "born_blocked", "gate" => "operator" }
        }
      }
    )
    sign_in_as(@user)
  end

  test "creates work and sends a task-scoped message from the cockpit" do
    visit control_room_path

    assert_text "Control Room"
    assert_text "pane 0"
    within("[data-board-section='needs-you']") do
      assert_text "Operator ruling required before execution."
    end
    find("summary", text: "Create new work").click
    within("form[action='#{control_room_tasks_path}']") do
      select "pane 0 — wezbridge (idle)", from: "Work context"
      fill_in "title", with: "Ship a focused fix"
      fill_in "brief", with: "Implement and verify the requested change."
      click_button "Create task"
    end

    assert_text "Task queued as intent"
    visit control_room_path(task_id: @task.id)
    assert_selector "#task-thread[role='complementary'][data-persistent-drawer='true']"
    assert_text "Gate · operator"
    within("#task-thread") do
      fill_in "content", with: "Please show the exact test evidence."
      click_button "Reply"
    end

    assert_text "Message queued as intent"
    assert_equal %w[create_task message], @user.orchestration_intents.order(:id).pluck(:kind)
  end

  test "asks pane 0 for a fleet assessment without choosing one project" do
    visit control_room_path

    within("form[action='#{control_room_ask_path}']") do
      assert_equal "_fleet", find_field("Question context").value
      fill_in "Question title", with: "Assess every open pane"
      fill_in "Question", with: "Recommend the next action for every live project."
      click_button "Ask pane 0"
    end

    assert_text "Question queued as intent"
    intent = @user.orchestration_intents.order(:id).last
    assert_equal "_fleet", intent.payload["project"]
    assert_equal "question", intent.payload["kind"]
  end

  test "opens the existing full task panel from the quick reply drawer" do
    visit control_room_path(task_id: @task.id)

    within("#task-thread") { click_link "Open full task" }

    if ApplicationSystemTestCase::CHROME_AVAILABLE
      assert_selector "[data-controller~='task-modal']", wait: 8
      assert_text "Review the canary"
    else
      assert_current_path board_task_path(@task.board, @task)
      assert_text "Confirm the live evidence."
    end
  end

  test "refreshes cockpit state without clearing a draft" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit control_room_path
    find("summary", text: "Create new work").click
    fill_in "Task title", with: "Keep this draft"

    @user.tasks.create!(
      board: boards(:one),
      name: "Appeared without a reload",
      description: "Live dashboard proof.",
      origin_session_id: "T-0002",
      origin_session_key: "wezbridge:primary:task:T-0002",
      status: :in_progress,
      state_data: {
        "orchestration" => {
          "profile" => "primary",
          "source_state" => "running",
          "project" => "wezbridge"
        }
      }
    )

    assert_text "Appeared without a reload", wait: 8
    assert_field "Task title", with: "Keep this draft"
    assert_text "Live cockpit · updated just now"
  end

  test "switches work lanes and keeps the selected detail beside the list" do
    @user.tasks.create!(
      board: boards(:one),
      name: "Running live verification",
      description: "Observe the live release.",
      origin_session_id: "T-0002",
      origin_session_key: "wezbridge:primary:task:T-0002",
      status: :in_progress,
      state_data: {
        "orchestration" => {
          "profile" => "primary",
          "source_state" => "running",
          "project" => "clawtrol"
        }
      }
    )

    visit control_room_path
    click_link "In progress"

    assert_selector "[data-workspace-panel='running']:not(.hidden)"
    click_link "Running live verification"
    assert_selector "#task-thread[data-persistent-drawer='true']"
    assert_text "Running live verification"
    assert_selector "[data-workspace-panel='running']:not(.hidden)"
  end
end
