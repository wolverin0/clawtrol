# frozen_string_literal: true

require "test_helper"

class TaskRunTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @board = Board.first || Board.create!(name: "Test Board", user: @user)
    @task = Task.create!(name: "Task for runs", board: @board, user: @user, status: "in_progress")
  end

  def build_run(attrs = {})
    TaskRun.new({
      task: @task,
      run_id: SecureRandom.uuid,
      run_number: 1,
      recommended_action: "in_review"
    }.merge(attrs))
  end

  # --- Validations ---
  test "valid with required fields" do
    tr = build_run
    assert tr.valid?
  end

  test "requires run_id" do
    tr = build_run(run_id: nil)
    assert_not tr.valid?
  end

  test "requires run_number" do
    tr = build_run(run_number: nil)
    assert_not tr.valid?
  end

  test "requires recommended_action" do
    tr = build_run(recommended_action: nil)
    assert_not tr.valid?
  end

  test "run_id must be unique" do
    uuid = SecureRandom.uuid
    build_run(run_id: uuid).save!
    dup = build_run(run_id: uuid, run_number: 2)
    assert_not dup.valid?
    assert_includes dup.errors[:run_id], "has already been taken"
  end

  test "recommended_action must be in RECOMMENDED_ACTIONS" do
    tr = build_run(recommended_action: "dance")
    assert_not tr.valid?
    assert_includes tr.errors[:recommended_action], "is not included in the list"
  end

  test "accepts all valid recommended_actions" do
    TaskRun::RECOMMENDED_ACTIONS.each_with_index do |action, i|
      tr = build_run(recommended_action: action, run_id: SecureRandom.uuid, run_number: i + 10)
      assert tr.valid?, "Expected '#{action}' to be valid"
    end
  end

  # --- Associations ---
  test "belongs_to task" do
    tr = build_run
    tr.save!
    assert_equal @task, tr.task
  end

  test "task has_many task_runs with dependent destroy" do
    build_run(run_number: 1).save!
    build_run(run_number: 2, run_id: SecureRandom.uuid).save!
    assert_equal 2, @task.task_runs.count
    @task.destroy
    assert_equal 0, TaskRun.where(task_id: @task.id).count
  end

  # --- Data integrity ---
  test "run_number unique per task" do
    build_run(run_number: 1).save!
    dup = build_run(run_number: 1, run_id: SecureRandom.uuid)
    # uniqueness: { scope: :factory_loop_id } — check if this constraint exists on task_id
    # The schema has: index_task_runs_on_task_id_and_run_number unique
    # This is a DB-level constraint, may raise on save
    assert_not dup.valid? || (dup.save rescue false) == false
  end

  test "stores summary and evidence" do
    tr = build_run(summary: "Completed the refactoring", evidence: ["test passed", "lint clean"])
    tr.save!
    tr.reload
    assert_equal "Completed the refactoring", tr.summary
    assert_includes tr.evidence, "test passed"
  end

  test "stores achieved and remaining arrays" do
    tr = build_run(achieved: ["extracted concern"], remaining: ["add tests"])
    tr.save!
    tr.reload
    assert_equal ["extracted concern"], tr.achieved
    assert_equal ["add tests"], tr.remaining
  end

  test "needs_follow_up defaults to false" do
    tr = build_run
    tr.save!
    assert_not tr.needs_follow_up?
  end

  test "stores model_used" do
    tr = build_run(model_used: "codex")
    tr.save!
    assert_equal "codex", tr.reload.model_used
  end
end
