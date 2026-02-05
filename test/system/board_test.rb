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

    # Verify all kanban columns are present
    assert_selector "h2", text: "Inbox"
    assert_selector "h2", text: "Up Next"
    assert_selector "h2", text: "In Progress"
    assert_selector "h2", text: "In Review"
    assert_selector "h2", text: "Done"

    # Verify board header is present
    assert_selector "[data-controller='board']"
  end

  test "board shows existing tasks" do
    visit board_path(@board)

    # The fixture task should be visible
    assert_text @task.name
  end

  test "task modal opens on card click" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Find and click the task card
    find("#task_#{@task.id}").click

    # Wait for modal to appear (Turbo Frame)
    assert_selector "[data-controller='task-modal']", wait: 5

    # Verify modal contains task details
    within "[data-controller='task-modal']" do
      assert_field "task[name]", with: @task.name
    end
  end

  test "task modal closes on clicking backdrop" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Open modal
    find("#task_#{@task.id}").click
    assert_selector "[data-controller='task-modal']", wait: 5

    # Close by clicking backdrop
    find("[data-task-modal-target='backdrop']", visible: :all).click(x: 0, y: 0)

    # Modal should be hidden (the element may still exist but be hidden)
    # Give it time to animate away
    sleep 0.5
    assert_no_selector "[data-task-modal-target='modal']:not(.hidden)", wait: 2
  end

  test "inline add card form appears on button click" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Find the "Add a card" button in the Inbox column and click it
    within "[data-status='inbox']" do
      click_button "Add a card"

      # Form should appear
      assert_selector "textarea[placeholder='Enter a title for this card...']", wait: 2
      assert_button "Add card"
    end
  end

  test "columns display task counts" do
    visit board_path(@board)

    # Each column should have a count badge
    # Look for count spans in each column
    assert_selector "span[id^='column-'][id$='-count']", minimum: 5
  end

  test "board loads without errors" do
    # Basic smoke test - page should load without 500 error
    visit board_path(@board)

    # Page title should be set
    assert_title "#{@board.name} - clawdeck"

    # No error messages visible
    assert_no_text "Something went wrong"
    assert_no_text "We're sorry, but something went wrong"
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

  test "file viewer panel shows when task has output files" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Click task to open modal
    find("#task_#{@task.id}").click
    assert_selector "[data-controller='task-modal']", wait: 5

    # Look for output files section in the task panel
    # The panel should show file links when output_files are present
    within "[data-controller='task-modal']" do
      # Check for file viewer controller or output files section
      # The exact structure depends on how output_files are rendered
      assert_selector "[data-controller='file-viewer']" if @task.output_files.present?
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
    assert_current_path(/boards/)
  end

  test "board is responsive on different screen sizes" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)

    # Board should have responsive classes
    assert_selector ".flex.gap-3", wait: 2

    # Columns should be present and have proper width classes
    assert_selector "[data-status]", minimum: 5
  end
end
