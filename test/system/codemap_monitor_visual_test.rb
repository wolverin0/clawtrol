# frozen_string_literal: true

require "application_system_test_case"
require "fileutils"
require "timeout"

class CodemapMonitorVisualTest < ApplicationSystemTestCase
  setup do
    @user = User.find_or_initialize_by(email_address: "visual@example.com")
    if @user.new_record? || @user.password_digest.blank?
      @user.password = "password123"
      @user.password_confirmation = "password123"
      @user.save!
    end

    board = @user.boards.first || @user.boards.create!(name: "Visual QA", icon: "H", color: "blue")
    seed_visual_tasks(board)
  end

  test "codemap hotel visual states" do
    sign_in_as(@user)

    visit codemap_monitor_path
    assert_text "Codemap Hotel"
    assert_selector "canvas[data-codemap-monitor-target='hotelCanvas']"

    capture_screenshot("codemap_hotel")

    @moving_task.update!(status: :in_progress)
    wait_for_renderer_status(@moving_task.id, "in_progress")
    capture_screenshot("codemap_hotel_transition")

    click_button "Tech"
    assert_selector "[data-codemap-monitor-target='techPanel']:not(.hidden)"
    capture_screenshot("codemap_tech")

    click_button "Hotel"
    assert_selector "[data-codemap-monitor-target='hotelPanel']:not(.hidden)"
  end

  private

  def seed_visual_tasks(board)
    Task.create!(
      user: @user,
      board: board,
      name: "Inbox Guest",
      status: :inbox,
      assigned_to_agent: true
    )
    @moving_task = Task.create!(
      user: @user,
      board: board,
      name: "Up Next Guest",
      status: :up_next
    )
    Task.create!(
      user: @user,
      board: board,
      name: "In Progress Guest",
      status: :in_progress
    )
    Task.create!(
      user: @user,
      board: board,
      name: "In Review Guest",
      status: :in_review
    )
    Task.create!(
      user: @user,
      board: board,
      name: "Done Guest",
      status: :done,
      assigned_to_agent: true
    )
  end

  def capture_screenshot(name)
    FileUtils.mkdir_p(Rails.root.join("tmp", "screenshots"))
    suffix = ENV.fetch("SCREENSHOT_SUFFIX", "after")
    save_screenshot(Rails.root.join("tmp", "screenshots", "#{name}_#{suffix}.png"))
  end

  def wait_for_renderer_status(task_id, status)
    Timeout.timeout(5) do
      loop do
        tasks = page.evaluate_script(<<~JS)
          (() => {
            const element = document.querySelector('[data-controller="codemap-monitor"]')
            const controller = window.Stimulus?.getControllerForElementAndIdentifier(element, "codemap-monitor")
            const entries = controller?.renderer?.tasks || []
            return entries.map((task) => ({ id: task.id, status: task.status }))
          })()
        JS
        match = tasks.find { |task| task["id"] == task_id.to_s }
        return if match && match["status"] == status
        sleep 0.2
      end
    end
  rescue Timeout::Error
    flunk("Timed out waiting for renderer to update task #{task_id} to #{status}")
  end
end
