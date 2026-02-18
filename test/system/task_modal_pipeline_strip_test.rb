require "application_system_test_case"

class TaskModalPipelineStripTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)

    @task.update!(user: @user, board: @board, pipeline_enabled: true, pipeline_stage: "triaged")

    sign_in_as(@user)
  end

  test "task modal renders pipeline information" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit board_path(@board)
    assert_selector "h2", text: "Inbox", wait: 5

    find("#task_#{@task.id} a[data-turbo-frame='task_panel']").click
    assert_selector "turbo-frame#task_panel [data-controller*='task-modal']", wait: 10
  end
end
