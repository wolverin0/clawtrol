# frozen_string_literal: true

require "test_helper"

class PipelineDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
  end

  test "should redirect to login when not authenticated" do
    get pipeline_dashboard_path
    assert_response :redirect
  end

  test "should get show when authenticated" do
    sign_in_as(@user)

    Task.create!(
      user: @user,
      board: @board,
      name: "Pipeline enabled task",
      status: :in_progress,
      priority: :none,
      pipeline_enabled: true,
      pipeline_stage: "triaged",
      routed_model: "openai/gpt-4.1-mini",
      pipeline_log: [ { stage: "triage", at: Time.current.iso8601 } ]
    )

    get pipeline_dashboard_path
    assert_response :success
    assert_select "h2", /Pipeline Dashboard/
    assert_select "div", /Pipeline enabled task/
  end

  test "filters by stage" do
    sign_in_as(@user)

    Task.create!(
      user: @user,
      board: @board,
      name: "Triaged task",
      status: :in_progress,
      priority: :none,
      pipeline_enabled: true,
      pipeline_stage: "triaged"
    )

    get pipeline_dashboard_path(pipeline_stage: "triaged")
    assert_response :success
    assert_includes response.body, "Triaged task"

    get pipeline_dashboard_path(pipeline_stage: "routed")
    assert_response :success
    assert_not_includes response.body, "Triaged task"
  end
end
