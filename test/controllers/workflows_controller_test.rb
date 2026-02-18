# frozen_string_literal: true

require "test_helper"

class WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @workflow = workflows(:one)
  end

  test "requires authentication" do
    sign_out
    get workflows_path
    assert_response :redirect
  end

  test "index renders" do
    get workflows_path
    assert_response :success
  end

  test "create workflow" do
    assert_difference "Workflow.count", 1 do
      post workflows_path, params: {
        workflow: { title: "My DAG", active: "0", definition: "{\"nodes\":[],\"edges\":[]}" }
      }
    end

    w = Workflow.order(:created_at).last
    assert_equal "My DAG", w.title
    assert_equal false, w.active
    assert_equal({ "nodes" => [], "edges" => [] }, w.definition)
  end

  test "update workflow" do
    patch workflow_path(@workflow), params: {
      workflow: { title: "Updated", active: "1", definition: "{\"nodes\":[],\"edges\":[]}" }
    }

    assert_redirected_to editor_workflow_path(@workflow)
    assert_equal "Updated", @workflow.reload.title
    assert_equal true, @workflow.active
  end

  test "cannot update global workflow" do
    global = workflows(:global_workflow)
    patch workflow_path(global), params: {
      workflow: { title: "Hacked" }
    }
    assert_redirected_to workflows_path
    assert_nil global.reload.title.match(/Hacked/)
  end

  test "cannot update other users workflow" do
    other = workflows(:other_user_workflow)
    patch workflow_path(other), params: {
      workflow: { title: "Stolen" }
    }
    # for_user scope doesn't include other user's workflows, so 404
    assert_response :not_found
  end

  test "update via JSON format returns forbidden for global workflow" do
    global = workflows(:global_workflow)
    patch workflow_path(global), params: {
      workflow: { title: "Hacked" }
    }, as: :json
    assert_response :forbidden
  end

  private
end
