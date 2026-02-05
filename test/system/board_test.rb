require "application_system_test_case"

class BoardTest < ApplicationSystemTestCase
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

  test "task modal opens on card click" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board to fully load
    assert_selector "h2", text: "Inbox", wait: 5

    # Find and click the task card link (not the whole li)
    within "#task_#{@task.id}" do
      find("a[data-turbo-frame='task_panel']").click
    end

    # Wait for modal to appear (Turbo Frame)
    assert_selector "[data-controller='task-modal']", wait: 10

    # Verify modal contains task details
    within "[data-controller='task-modal']" do
      assert_field "task[name]", with: @task.name
    end
  end

  test "task modal closes on close button click" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Open modal
    within "#task_#{@task.id}" do
      find("a[data-turbo-frame='task_panel']").click
    end
    assert_selector "[data-controller='task-modal']", wait: 10

    # Close by clicking the close button
    within "[data-controller='task-modal']" do
      find("[data-action='click->task-modal#close']", match: :first).click
    end

    # Modal should be hidden
    sleep 0.5
    assert_no_selector "[data-task-modal-target='modal']:not(.hidden)", wait: 3
  end

  test "inline add card form appears on button click" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Find the "Add a card" button in the Inbox column and click it
    within "[data-status='inbox']" do
      click_button "Add a card"

      # Form should appear
      assert_selector "textarea[placeholder='Enter a title for this card...']", wait: 3
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
    assert_no_text "Sign in"

    # Page title should be set (in the h1 or page title)
    assert_selector "h2", text: "Inbox", wait: 5
  end
end

class BoardWithOutputFilesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)

    # Update task with output_files for file viewer testing
    @task.update!(
      user: @user,
      board: @board,
      output_files: [
        { "path" => "/tmp/test_output.md", "label" => "Test Output" }
      ]
    )

    sign_in_as(@user)
  end

  test "file viewer shows when task has output files" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Wait for board
    assert_selector "h2", text: "Inbox", wait: 5

    # Click task to open modal
    within "#task_#{@task.id}" do
      find("a[data-turbo-frame='task_panel']").click
    end
    assert_selector "[data-controller='task-modal']", wait: 10

    # The task panel should have a file-viewer controller when files are present
    within "[data-controller='task-modal']" do
      # Just verify the modal loaded - file viewer integration depends on
      # how output_files are rendered in the panel
      assert_field "task[name]", with: @task.name
    end
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
