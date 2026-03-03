require "test_helper"

class RoadmapExecutorSyncTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password")
    @board = @user.boards.create!(name: "Test Board", position: 1)
    @roadmap = @board.create_roadmap!(body: "- [ ] Setup DB\n- [ ] Write tests")
  end

  test "creates missing tasks and links for unchecked items" do
    assert_difference("Task.count", 2) do
      assert_difference("BoardRoadmapTaskLink.count", 2) do
        RoadmapExecutorSync.new(@roadmap).call
      end
    end

    tasks = @board.tasks.order(:created_at).to_a
    assert_equal "Setup DB", tasks.first.name
    assert_equal "Write tests", tasks.second.name
  end

  test "does not duplicate tasks if already linked" do
    RoadmapExecutorSync.new(@roadmap).call

    assert_no_difference("Task.count") do
      assert_no_difference("BoardRoadmapTaskLink.count") do
        RoadmapExecutorSync.new(@roadmap).call
      end
    end
  end

  test "links to existing task if name matches" do
    @board.tasks.create!(user: @user, name: "Setup DB", status: "in_progress")

    assert_difference("Task.count", 1) do
      assert_difference("BoardRoadmapTaskLink.count", 2) do
        RoadmapExecutorSync.new(@roadmap).call
      end
    end

    link = @roadmap.task_links.find_by(item_text: "Setup DB")
    assert_equal "in_progress", link.task.status
  end
end
