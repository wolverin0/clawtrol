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
          "project" => "whatsappbot"
        }
      }
    )
    sign_in_as(@user)
  end

  test "creates work and sends a task-scoped message from the cockpit" do
    visit control_room_path(task_id: @task.id)

    assert_text "Control Room"
    assert_text "pane 0"
    within("form[action='#{control_room_tasks_path}']") do
      select "pane 0 — wezbridge (idle)", from: "Target pane / project"
      fill_in "title", with: "Ship a focused fix"
      fill_in "brief", with: "Implement and verify the requested change."
      click_button "Create task"
    end

    assert_text "Task queued as intent"
    visit control_room_path(task_id: @task.id)
    within("#task-thread") do
      fill_in "content", with: "Please show the exact test evidence."
      click_button "Send"
    end

    assert_text "Message queued as intent"
    assert_equal %w[create_task message], @user.orchestration_intents.order(:id).pluck(:kind)
  end
end
