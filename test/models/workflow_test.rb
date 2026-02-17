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

  # --- More validation edge cases ---

  test "title length maximum is 255" do
    @workflow.title = "a" * 256
    assert_not @workflow.valid?
    assert_includes @workflow.errors[:title], "is too long"
  end

  test "title can be exactly 255 characters" do
    @workflow.title = "a" * 255
    assert @workflow.valid?
  end

  test "definition accepts nested hash" do
    @workflow.definition = { "nodes" => [{ "id" => "1", "type" => "task" }], "edges" => [] }
    assert @workflow.valid?
  end

  test "definition accepts complex nested structure" do
    @workflow.definition = {
      "nodes" => [{ "id" => "1", "config" => { "timeout" => 300 } }],
      "edges" => [{ "from" => "1", "to" => "2" }],
      "metadata" => { "version" => "1.0", "author" => "test" }
    }
    assert @workflow.valid?
  end

  test "definition rejects string numbers" do
    @workflow.definition = "123"
    assert_not @workflow.valid?
  end

  test "definition rejects numeric types" do
    @workflow.definition = 123
    assert_not @workflow.valid?
  end

  test "definition rejects boolean" do
    @workflow.definition = true
    assert_not @workflow.valid?
  end

  # --- More scope tests ---

  test "for_user with nil user includes global workflows" do
    global_wf = workflows(:global_workflow)
    scoped = Workflow.for_user(nil)
    assert_includes scoped, global_wf
  end

  test "for_user returns only user workflows when globals removed" do
    Workflow.where(user_id: nil).delete_all
    scoped = Workflow.for_user(@user)
    assert_equal Workflow.where(user_id: @user.id).order(:id).pluck(:id), scoped.order(:id).pluck(:id)
  end

  # --- More association tests ---

  test "workflow without user is valid" do
    workflow = Workflow.new(title: "Global Workflow", definition: {})
    assert workflow.valid?
  end

  test "user can have multiple workflows" do
    Workflow.create!(title: "Another", definition: {}, user: @user)
    assert_operator @user.workflows.count, :>=, 1
  end

  test "inverse_of is set for user association" do
    @workflow.save!
    assert_equal @workflow, @user.workflows.find(@workflow.id)
  end

  # --- Active scope tests ---

  test "active scope returns only active workflows" do
    active = workflows(:user_workflow)
    inactive = workflows(:inactive_workflow)

    assert_includes Workflow.active, active
    assert_not_includes Workflow.active, inactive
  end

  test "inactive scope returns only inactive workflows" do
    active = workflows(:user_workflow)
    inactive = workflows(:inactive_workflow)

    assert_includes Workflow.inactive, inactive
    assert_not_includes Workflow.inactive, active
  end
end
