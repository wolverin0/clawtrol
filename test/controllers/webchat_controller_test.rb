# frozen_string_literal: true

require "test_helper"
class WebchatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
    @task_one = tasks(:one)   # belongs to user_one
    @task_two = tasks(:two)   # belongs to user_two
  end

  test "requires authentication" do
    get webchat_path
    assert_response :redirect
  end

  test "renders webchat page for authenticated user" do
    sign_in_as(@user_one)
    get webchat_path
    assert_response :success
  end

  test "loads own task when task_id param matches user" do
    sign_in_as(@user_one)
    get webchat_path(task_id: @task_one.id)
    assert_response :success
    assert_includes response.body, "##{@task_one.id}"
    assert_includes response.body, @task_one.name
    refute_includes response.body, "<iframe"
    refute_includes response.body, "webchat-embed"
  end

  test "does NOT load another user's task (IDOR protection)" do
    sign_in_as(@user_one)
    get webchat_path(task_id: @task_two.id)
    assert_response :success
    # Should NOT include task two's context since it belongs to user_two
    refute_includes response.body, @task_two.name
  end

  test "handles non-existent task_id gracefully" do
    sign_in_as(@user_one)
    get webchat_path(task_id: 999999)
    assert_response :success
  end

  test "renders without task_id param" do
    sign_in_as(@user_one)
    get webchat_path
    assert_response :success
  end
end
