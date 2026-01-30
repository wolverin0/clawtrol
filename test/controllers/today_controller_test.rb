require "test_helper"

class TodayControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get show" do
    get today_url
    assert_response :success
  end

  test "should show tasks due today" do
    # Create a task due today
    inbox = @user.inbox
    task = inbox.tasks.create!(
      name: "Today task",
      due_date: Date.current,
      task_list: inbox.default_task_list,
      user: @user
    )

    get today_url
    assert_response :success
    assert_select "li#task_#{task.id}"
  end

  test "should show overdue tasks" do
    # Create an overdue task
    inbox = @user.inbox
    task = inbox.tasks.create!(
      name: "Overdue task",
      due_date: Date.current - 1.day,
      task_list: inbox.default_task_list,
      user: @user
    )

    get today_url
    assert_response :success
    assert_select "li#task_#{task.id}"
  end

  test "should not show tasks due in the future" do
    # Create a future task
    inbox = @user.inbox
    task = inbox.tasks.create!(
      name: "Future task",
      due_date: Date.current + 1.day,
      task_list: inbox.default_task_list,
      user: @user
    )

    get today_url
    assert_response :success
    assert_select "li#task_#{task.id}", false
  end

  test "should not show completed tasks in main list" do
    # Create a completed task due today
    inbox = @user.inbox
    task = inbox.tasks.create!(
      name: "Completed task",
      due_date: Date.current,
      task_list: inbox.default_task_list,
      user: @user,
      completed: true,
      completed_at: Time.current
    )

    get today_url
    assert_response :success
    # The task should be in the completed section, not the main list
    assert_select "ul#tasks-list li#task_#{task.id}", false
  end
end
