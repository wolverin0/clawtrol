# frozen_string_literal: true

require "test_helper"

class TaskFollowupServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @parent = @board.tasks.create!(
      name: "Parent task",
      description: "Something to follow up on",
      user: @user,
      status: :in_review,
      model: "opus"
    )
  end

  test "creates followup and completes parent in one transaction" do
    result = TaskFollowupService.new(@parent).call(name: "Next steps")

    assert result.success?, "Expected success but got error: #{result.error}"
    assert_equal "Next steps", result.followup.name
    assert_equal "inbox", result.followup.status
    assert_equal @parent.id, result.followup.parent_task_id

    @parent.reload
    assert_equal "done", @parent.status
    assert @parent.completed?
    assert_not_nil @parent.completed_at
  end

  test "defaults name when blank" do
    result = TaskFollowupService.new(@parent).call

    assert result.success?
    assert_equal "Follow up: Parent task", result.followup.name
  end

  test "sets model override on followup" do
    result = TaskFollowupService.new(@parent).call(model: "codex")

    assert result.success?
    assert_equal "codex", result.followup.model
  end

  test "destination up_next assigns to agent" do
    result = TaskFollowupService.new(@parent).call(destination: "up_next")

    assert result.success?
    assert_equal "up_next", result.followup.status
    assert result.followup.assigned_to_agent?
    assert_not_nil result.followup.assigned_at
  end

  test "destination in_progress returns failure without runner lease" do
    # in_progress requires a runner lease or agent_session_id when assigned_to_agent is true.
    # Without one, the service should return a failure result and roll back.
    result = TaskFollowupService.new(@parent).call(destination: "in_progress")

    assert_not result.success?
    assert_includes result.error, "Runner Lease"

    # Parent should NOT be marked done (transaction rolled back)
    @parent.reload
    assert_equal "in_review", @parent.status
  end

  test "destination nightly sets nightly flag" do
    result = TaskFollowupService.new(@parent).call(destination: "nightly")

    assert result.success?
    assert_equal "up_next", result.followup.status
    assert result.followup.nightly?
    assert result.followup.assigned_to_agent?
  end

  test "continues session when requested" do
    result = TaskFollowupService.new(@parent).call(
      continue_session: true,
      inherit_session_key: "session-abc-123"
    )

    assert result.success?
    assert_equal "session-abc-123", result.followup.agent_session_key
  end

  test "does not set session key unless both params provided" do
    result = TaskFollowupService.new(@parent).call(
      continue_session: false,
      inherit_session_key: "session-abc-123"
    )

    assert result.success?
    assert_nil result.followup.agent_session_key
  end

  test "rolls back parent completion on followup validation error" do
    # Destination "in_progress" + assigned_to_agent without a runner lease
    # triggers a validation error that should roll back the whole transaction,
    # including the parent's status change to "done".
    result = TaskFollowupService.new(@parent).call(destination: "in_progress")

    assert_not result.success?
    assert_not_nil result.error

    @parent.reload
    assert_equal "in_review", @parent.status, "parent should not be completed on rollback"
    assert_not @parent.completed?, "parent should not be marked completed on rollback"
  end
end
