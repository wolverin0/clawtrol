# frozen_string_literal: true

require "test_helper"

class SwarmControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @idea = swarm_ideas(:code_idea)
  end

  # --- Authentication ---

  test "index requires authentication" do
    sign_out
    get swarm_path
    assert_response :redirect
  end

  # --- Index ---

  test "index renders" do
    get swarm_path
    assert_response :success
  end

  test "index excludes disabled ideas" do
    get swarm_path
    assert_response :success
    # disabled_idea should not appear in @ideas (which uses .enabled scope)
  end

  # --- Create ---

  test "create with valid params" do
    assert_difference "SwarmIdea.count", 1 do
      post create_swarm_idea_path, params: {
        swarm_idea: {
          title: "New swarm idea",
          description: "Test description",
          category: "code",
          suggested_model: "opus",
          estimated_minutes: 20
        }
      }
    end
    assert_redirected_to swarm_path
    assert_equal @user.id, SwarmIdea.last.user_id
  end

  test "create with missing title fails" do
    assert_no_difference "SwarmIdea.count" do
      post create_swarm_idea_path, params: {
        swarm_idea: { title: "", category: "code" }
      }
    end
    assert_redirected_to swarm_path
    assert flash[:alert].present?
  end

  # --- Launch ---

  test "launch creates task from idea" do
    assert_difference "Task.count", 1 do
      post swarm_launch_path(@idea)
    end
    assert_redirected_to swarm_path

    task = Task.order(:created_at).last
    assert_equal @idea.title, task.name
    assert_equal "up_next", task.status
    assert_includes task.tags, "swarm"
    assert_equal 1, @idea.reload.times_launched
  end

  test "launch with JSON format" do
    post swarm_launch_path(@idea), as: :json
    assert_response :success

    body = response.parsed_body
    assert body["success"]
    assert body["task_id"].present?
    assert_equal @idea.title, body["name"]
  end

  test "launch with custom model override" do
    post swarm_launch_path(@idea), params: { model: "sonnet" }
    assert_redirected_to swarm_path

    task = Task.order(:created_at).last
    assert_equal "sonnet", task.model
  end

  test "launch cannot access other users idea" do
    other_user = users(:two)
    other_idea = SwarmIdea.create!(user: other_user, title: "Other idea", category: "code", enabled: true)

    post swarm_launch_path(other_idea)
    assert_response :not_found
  end

  # --- Update ---

  test "update idea" do
    patch update_swarm_idea_path(@idea), params: {
      swarm_idea: { title: "Updated title" }
    }
    assert_redirected_to swarm_path
    assert_equal "Updated title", @idea.reload.title
  end

  test "update with JSON" do
    patch update_swarm_idea_path(@idea), params: {
      swarm_idea: { title: "JSON updated" }
    }, as: :json
    assert_response :success
    assert_equal "JSON updated", @idea.reload.title
  end

  test "cannot update other users idea" do
    other_user = users(:two)
    other_idea = SwarmIdea.create!(user: other_user, title: "Other", category: "code", enabled: true)

    patch update_swarm_idea_path(other_idea), params: {
      swarm_idea: { title: "Hacked" }
    }
    assert_response :not_found
    assert_equal "Other", other_idea.reload.title
  end

  # --- Toggle Favorite ---

  test "toggle favorite" do
    assert_not @idea.favorite
    patch toggle_favorite_swarm_idea_path(@idea), as: :json
    assert_response :success

    body = response.parsed_body
    assert body["success"]
    assert body["favorite"]
    assert @idea.reload.favorite
  end

  # --- Destroy ---

  test "destroy idea" do
    assert_difference "SwarmIdea.count", -1 do
      delete destroy_swarm_idea_path(@idea)
    end
    assert_redirected_to swarm_path
  end

  test "cannot destroy other users idea" do
    other_user = users(:two)
    other_idea = SwarmIdea.create!(user: other_user, title: "Protected", category: "code", enabled: true)

    assert_no_difference "SwarmIdea.count" do
      delete destroy_swarm_idea_path(other_idea)
    end
    assert_response :not_found
  end
end
