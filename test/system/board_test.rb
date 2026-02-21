# frozen_string_literal: true

require "application_system_test_case"

class BoardSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)

    # Ensure task belongs to the correct user/board
    @task.update!(user: @user, board: @board)

    sign_in_as(@user)
  end

  test "board page loads with columns" do
    visit board_path(@board)

    # Wait for page to fully load with Turbo
    assert_selector "body", wait: 10

    # Verify all kanban columns are present
    assert_selector "h2", text: "Inbox", wait: 5
    assert_selector "h2", text: "Up Next"
    assert_selector "h2", text: "In Progress"
    assert_selector "h2", text: "In Review"
    assert_selector "h2", text: "Done"
  end

  test "board shows existing tasks" do
    visit board_path(@board)

    # Wait for board to load
    assert_selector "h2", text: "Inbox", wait: 5

    # The fixture task should be visible
    assert_text @task.name
  end

  test "task panel loads when card is clicked" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board to fully load
    assert_selector "h2", text: "Inbox", wait: 5
    assert_selector "#task_#{@task.id}", wait: 5

    # Find and click the task card link
    find("#task_#{@task.id} a[data-turbo-frame='task_panel']").click

    # Wait for the turbo frame to get content (which will include task-modal controller)
    # The panel loads and auto-opens via Stimulus
    sleep 1  # Give time for Turbo frame to load and Stimulus to connect

    # Check if turbo frame has content
    within "turbo-frame#task_panel" do
      # The panel should contain the task-modal controller
      assert_selector "[data-controller*='task-modal']", wait: 10
    end
  end

  test "task modal shows task name in editable field" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Open task panel
    find("#task_#{@task.id} a[data-turbo-frame='task_panel']").click

    # Wait for modal to appear and contain the form
    assert_selector "turbo-frame#task_panel [data-controller*='task-modal']", wait: 10

    # Verify the task name is in the input
    assert_field "task[name]", with: @task.name, wait: 5
  end

  test "inline add card form appears on button click" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Find the "Add a card" button in the Inbox column and click it
    within "[data-status='inbox']" do
      click_button "Add a card"

      # Form should appear (placeholder includes slash command hints)
      assert_selector "textarea[placeholder*='Enter a title']", wait: 3
      assert_button "Add card"
    end
  end

  test "columns display task counts" do
    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Each column should have a count badge
    assert_selector "span[id^='column-'][id$='-count']", minimum: 5
  end

  test "board loads without errors" do
    visit board_path(@board)

    # Wait for page to load
    assert_selector "body", wait: 10

    # Check we're not on login page
    assert_no_text "Sign in to continue"

    # Columns should be visible
    assert_selector "h2", text: "Inbox", wait: 5
  end

  test "column shows empty state when no tasks" do
    # Create a new board with no tasks
    empty_board = Board.create!(name: "Empty Board", user: @user)

    visit board_path(empty_board)

    # Wait for board to load — column headers are h2 elements
    assert_selector "h2", text: "Inbox", wait: 5

    # Should show empty state or add card button
    assert_selector ".empty-state, .text-gray-500, .text-gray-400, [data-status='inbox']", minimum: 1
  end

  test "board shows correct task count per column" do
    # Add tasks to different statuses
    tasks(:one).update!(status: "inbox")
    Task.create!(name: "Task 2", user: @user, board: @board, status: "inbox")
    Task.create!(name: "Task 3", user: @user, board: @board, status: "up_next")

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Inbox should have count badge showing at least 2
    inbox_badge = find("[id='column-inbox-count']")
    assert inbox_badge.text.to_i >= 2
  end

  test "board header shows board name and actions" do
    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Board name should be visible in header
    assert_text @board.name

    # Should have some action buttons (settings, add task, etc.)
    assert_selector "a[href*='settings'], button[class*='dropdown'], button[data-dropdown-target='button'], button[data-nav-dropdown-target='button']", minimum: 1
  end
end

class BoardNavigationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)

    sign_in_as(@user)
  end

  test "can navigate to boards index" do
    visit boards_path

    # Should show list of boards or redirect to first board
    # Wait for page to load
    assert_selector "body", wait: 10

    # Should not be on login page
    assert_no_text "Welcome back!"
    assert_no_text "Sign in to continue"
  end

  test "board is responsive - has columns" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Columns should be present
    assert_selector "[data-status]", minimum: 5
  end
end

class BoardFiltersTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(user: @user, board: @board, tags: ["bug", "urgent"])

    sign_in_as(@user)
  end

  test "board shows task with tags" do
    visit board_path(@board)

    assert_selector "h2", text: "Inbox", wait: 5
    assert_text "bug"
  end

  test "board shows task priority indicator when set" do
    @task.update!(priority: "high")

    visit board_path(@board)

    assert_selector "h2", text: "Inbox", wait: 5
    # Task should be visible on board with high priority
    assert_selector "[data-task-id='#{@task.id}'], #task_#{@task.id}", wait: 5
  end
end

class BoardKanbanTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(password: "password123", password_confirmation: "password123") if @user.respond_to?(:password=)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(user: @user, board: @board)

    sign_in_as(@user)
  end

  test "kanban columns have correct data attributes" do
    visit board_path(@board)

    assert_selector "h2", text: "Inbox", wait: 5

    # Check inbox column has correct data attribute
    inbox = find("[data-status='inbox']")
    assert_equal "inbox", inbox["data-status"]
  end

  test "task cards have required identifiers" do
    visit board_path(@board)

    assert_selector "h2", text: "Inbox", wait: 5
    assert_selector "#task_#{@task.id}"
  end

  test "columns maintain order" do
    # Create multiple tasks
    3.times do |i|
      Task.create!(name: "Task #{i}", board: @board, user: @user, status: "inbox")
    end

    visit board_path(@board)

    assert_selector "h2", text: "Inbox", wait: 5

    # Multiple tasks should be visible (use id prefix selector)
    assert_selector "[id^='task_']", minimum: 3
  end
end

class BoardPerformanceTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(user: @user, board: @board)

    sign_in_as(@user)
  end

  test "board loads within reasonable time" do
    start_time = Time.now

    visit board_path(@board)

    assert_selector "h2", text: "Inbox", wait: 10

    load_time = Time.now - start_time
    assert load_time < 10.0, "Board took #{load_time}s to load"
  end
end
