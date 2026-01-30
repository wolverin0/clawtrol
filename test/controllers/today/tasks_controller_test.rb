require "test_helper"

module Today
  class TasksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as(@user)
    end

    test "should create task with today's due date" do
      assert_difference("Task.count") do
        post today_tasks_url, params: { task: { name: "New today task" } }
      end

      task = Task.order(created_at: :desc).first
      assert_equal Date.current, task.due_date
      assert_equal @user.inbox, task.project
    end

    test "should create task in inbox" do
      post today_tasks_url, params: { task: { name: "New today task" } }

      task = Task.order(created_at: :desc).first
      assert task.project.inbox?
    end

    test "should redirect to today page after creation" do
      post today_tasks_url, params: { task: { name: "New today task" } }
      assert_redirected_to today_url
    end

    test "should respond with turbo stream" do
      post today_tasks_url, params: { task: { name: "New today task" } }, as: :turbo_stream
      assert_response :success
    end
  end
end
