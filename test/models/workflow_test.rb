# frozen_string_literal: true

require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @workflow = Workflow.new(title: "Test Workflow", definition: { "nodes" => [], "edges" => [] }, user: @user)
  end

  # --- Validations ---

  test "valid workflow saves" do
    assert @workflow.valid?
  end

  test "requires title" do
    @workflow.title = nil
    assert_not @workflow.valid?
    assert_includes @workflow.errors[:title], "can't be blank"
  end

  test "definition must be a hash" do
    @workflow.definition = "not a hash"
    assert_not @workflow.valid?
    assert_includes @workflow.errors[:definition].join, "must be a JSON object"
  end

  test "definition allows empty hash" do
    @workflow.definition = {}
    assert @workflow.valid?
  end

  test "definition rejects array" do
    @workflow.definition = []
    assert_not @workflow.valid?
  end

  test "definition rejects nil treated as hash" do
    @workflow.definition = nil
    assert_not @workflow.valid?
  end

  # --- Associations ---

  test "belongs_to user optionally" do
    @workflow.user = nil
    assert @workflow.valid?
  end

  test "user association loads" do
    @workflow.save!
    assert_equal @user, @workflow.user
  end

  # --- Scopes ---

  test "for_user includes user-owned and global workflows" do
    user_wf = workflows(:user_workflow)
    global_wf = workflows(:global_workflow)
    other_wf = workflows(:other_user_workflow)

    scoped = Workflow.for_user(@user)
    assert_includes scoped, user_wf
    assert_includes scoped, global_wf
    assert_not_includes scoped, other_wf
  end

  test "for_user excludes other users workflows" do
    other_user = users(:two)
    user1_wf = workflows(:user_workflow)

    scoped = Workflow.for_user(other_user)
    assert_not_includes scoped, user1_wf
    assert_includes scoped, workflows(:other_user_workflow)
  end

  # --- Fixture smoke tests ---

  test "fixtures load correctly" do
    assert workflows(:user_workflow).active?
    assert_not workflows(:inactive_workflow).active?
    assert_nil workflows(:global_workflow).user_id
  end
end
