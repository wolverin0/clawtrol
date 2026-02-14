# frozen_string_literal: true

require "test_helper"

class TaskPipelineStageTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
  end

  # --- Enum values ---

  test "pipeline_stage enum has all expected values" do
    expected = %w[unstarted classified researched planned dispatched verified pipeline_done]
    assert_equal expected, Task.pipeline_stages.keys
  end

  test "default pipeline_stage is unstarted" do
    task = Task.new(name: "Test", board: @board, user: @user)
    assert_equal "unstarted", task.pipeline_stage
  end

  # --- Valid transitions ---

  test "can transition from unstarted to classified" do
    task = create_task(pipeline_stage: :unstarted)
    task.pipeline_stage = :classified
    assert task.valid?, "Expected unstarted→classified to be valid: #{task.errors.full_messages}"
  end

  test "can transition from classified to researched" do
    task = create_task(pipeline_stage: :classified)
    task.pipeline_stage = :researched
    assert task.valid?, "Expected classified→researched to be valid: #{task.errors.full_messages}"
  end

  test "can transition from researched to planned" do
    task = create_task(pipeline_stage: :researched)
    task.pipeline_stage = :planned
    assert task.valid?, "Expected researched→planned to be valid: #{task.errors.full_messages}"
  end

  test "can transition from classified to planned (skip researched)" do
    task = create_task(pipeline_stage: :classified)
    task.pipeline_stage = :planned
    assert task.valid?, "Expected classified→planned to be valid (shortcut): #{task.errors.full_messages}"
  end

  test "can transition from planned to dispatched with execution_plan" do
    task = create_task(pipeline_stage: :planned, execution_plan: "1. Do the thing")
    task.pipeline_stage = :dispatched
    assert task.valid?, "Expected planned→dispatched with plan to be valid: #{task.errors.full_messages}"
  end

  test "can transition from dispatched to verified" do
    task = create_task(pipeline_stage: :dispatched, execution_plan: "plan for dispatch")
    task.pipeline_stage = :verified
    assert task.valid?, "Expected dispatched→verified to be valid: #{task.errors.full_messages}"
  end

  test "can transition from verified to pipeline_done" do
    task = create_task(pipeline_stage: :verified, execution_plan: "plan")
    task.pipeline_stage = :pipeline_done
    assert task.valid?, "Expected verified→pipeline_done to be valid: #{task.errors.full_messages}"
  end

  # --- Invalid transitions ---

  test "cannot skip from unstarted to planned" do
    task = create_task(pipeline_stage: :unstarted)
    task.pipeline_stage = :planned
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot skip from unstarted to dispatched" do
    task = create_task(pipeline_stage: :unstarted)
    task.pipeline_stage = :dispatched
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot go backwards from dispatched to classified" do
    task = create_task(pipeline_stage: :dispatched, execution_plan: "plan")
    task.pipeline_stage = :classified
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot skip from classified to verified" do
    task = create_task(pipeline_stage: :classified)
    task.pipeline_stage = :verified
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot go from pipeline_done backwards" do
    task = create_task(pipeline_stage: :pipeline_done, execution_plan: "plan")
    task.pipeline_stage = :dispatched
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  # --- Edge cases ---

  test "same stage is valid (no-op)" do
    task = create_task(pipeline_stage: :planned)
    task.pipeline_stage = :planned
    assert task.valid?, "Expected no-op transition to be valid"
  end

  test "new record can start at stages that don't require prerequisites" do
    %i[unstarted classified researched planned].each do |stage|
      task = Task.new(name: "Start at #{stage}", board: @board, user: @user, pipeline_stage: stage)
      assert task.valid?, "Expected new record at #{stage} to be valid: #{task.errors.full_messages}"
    end
  end

  test "new record at dispatched requires execution_plan" do
    task = Task.new(name: "Start at dispatched", board: @board, user: @user, pipeline_stage: :dispatched)
    assert_not task.valid?
    task.execution_plan = "Step 1: Do X"
    assert task.valid?, task.errors.full_messages.join(", ")
  end

  # --- PIPELINE_TRANSITIONS constant ---

  # --- Dispatched requires execution_plan ---

  test "cannot dispatch without execution_plan" do
    task = create_task(pipeline_stage: :planned)
    task.pipeline_stage = :dispatched
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "execution_plan"
  end

  test "can dispatch with execution_plan" do
    task = create_task(pipeline_stage: :planned, execution_plan: "Step 1: Do X\nStep 2: Do Y")
    task.pipeline_stage = :dispatched
    assert task.valid?, "Expected dispatch with plan to be valid: #{task.errors.full_messages}"
  end

  # --- PIPELINE_TRANSITIONS constant ---

  test "PIPELINE_TRANSITIONS covers all pipeline stages" do
    Task.pipeline_stages.keys.each do |stage|
      assert Task::PIPELINE_TRANSITIONS.key?(stage), "Missing PIPELINE_TRANSITIONS entry for #{stage}"
    end
  end

  private

  def create_task(pipeline_stage: :unstarted, **attrs)
    Task.create!({
      name: "Pipeline test #{SecureRandom.hex(4)}",
      board: @board,
      user: @user,
      pipeline_stage: pipeline_stage
    }.merge(attrs))
  end
end
