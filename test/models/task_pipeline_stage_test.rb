# frozen_string_literal: true

require "test_helper"

class TaskPipelineStageTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
  end

  # --- Enum values ---

  test "pipeline_stage enum has all expected values" do
    expected = %w[unstarted triaged context_ready routed executing verifying completed failed]
    assert_equal expected, Task.pipeline_stages.keys
  end

  test "default pipeline_stage is unstarted" do
    task = Task.new(name: "Test", board: @board, user: @user)
    assert_equal "unstarted", task.pipeline_stage
  end

  # --- Valid transitions ---

  test "can transition from unstarted to triaged" do
    task = create_task(pipeline_stage: :unstarted)
    task.pipeline_stage = :triaged
    assert task.valid?, "Expected unstarted→triaged to be valid: #{task.errors.full_messages}"
  end

  test "can transition from triaged to context_ready" do
    task = create_task(pipeline_stage: :triaged)
    task.pipeline_stage = :context_ready
    assert task.valid?, "Expected triaged→context_ready to be valid: #{task.errors.full_messages}"
  end

  test "can transition from context_ready to routed" do
    task = create_task(pipeline_stage: :context_ready)
    task.pipeline_stage = :routed
    assert task.valid?, "Expected context_ready→routed to be valid: #{task.errors.full_messages}"
  end

  test "can transition from routed to executing" do
    task = create_task(pipeline_stage: :routed, compiled_prompt: "Do the thing")
    task.pipeline_stage = :executing
    assert task.valid?, "Expected routed→executing to be valid: #{task.errors.full_messages}"
  end

  test "can transition from executing to verifying" do
    task = create_task(pipeline_stage: :executing, compiled_prompt: "Do the thing")
    task.pipeline_stage = :verifying
    assert task.valid?, "Expected executing→verifying to be valid: #{task.errors.full_messages}"
  end

  test "can transition from verifying to completed" do
    task = create_task(pipeline_stage: :verifying, compiled_prompt: "Do the thing")
    task.pipeline_stage = :completed
    assert task.valid?, "Expected verifying→completed to be valid: #{task.errors.full_messages}"
  end

  test "can transition from executing to completed (skip verifying)" do
    task = create_task(pipeline_stage: :executing, compiled_prompt: "Do the thing")
    task.pipeline_stage = :completed
    assert task.valid?, "Expected executing→completed (shortcut) to be valid: #{task.errors.full_messages}"
  end

  # --- Failed state transitions ---

  test "can transition from any active stage to failed" do
    %i[unstarted triaged context_ready routed].each do |stage|
      task = create_task(pipeline_stage: stage)
      task.pipeline_stage = :failed
      assert task.valid?, "Expected #{stage}→failed to be valid: #{task.errors.full_messages}"
    end
    # executing and verifying need compiled_prompt
    %i[executing verifying].each do |stage|
      task = create_task(pipeline_stage: stage, compiled_prompt: "Prompt for #{stage}")
      task.pipeline_stage = :failed
      assert task.valid?, "Expected #{stage}→failed to be valid: #{task.errors.full_messages}"
    end
  end

  test "can transition from failed back to triaged" do
    task = create_task(pipeline_stage: :failed)
    task.pipeline_stage = :triaged
    assert task.valid?, "Expected failed→triaged (retry) to be valid: #{task.errors.full_messages}"
  end

  # --- Invalid transitions ---

  test "cannot skip from unstarted to routed" do
    task = create_task(pipeline_stage: :unstarted)
    task.pipeline_stage = :routed
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot skip from unstarted to executing" do
    task = create_task(pipeline_stage: :unstarted)
    task.pipeline_stage = :executing
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot go backwards from routed to triaged" do
    task = create_task(pipeline_stage: :routed)
    task.pipeline_stage = :triaged
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot skip from triaged to executing" do
    task = create_task(pipeline_stage: :triaged, compiled_prompt: "Prompt")
    task.pipeline_stage = :executing
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  test "cannot go from completed backwards" do
    task = create_task(pipeline_stage: :completed, compiled_prompt: "Prompt")
    task.pipeline_stage = :executing
    assert_not task.valid?
    assert_includes task.errors[:pipeline_stage].join, "cannot transition"
  end

  # --- Edge cases ---

  test "same stage is valid (no-op)" do
    task = create_task(pipeline_stage: :triaged)
    task.pipeline_stage = :triaged
    assert task.valid?, "Expected no-op transition to be valid"
  end

  test "new record defaults to unstarted" do
    task = Task.new(name: "New task", board: @board, user: @user)
    assert_equal "unstarted", task.pipeline_stage
    assert task.valid?, task.errors.full_messages.join(", ")
  end

  # --- PIPELINE_TRANSITIONS constant ---

  test "PIPELINE_TRANSITIONS covers all pipeline stages" do
    Task.pipeline_stages.keys.each do |stage|
      assert Task::PIPELINE_TRANSITIONS.key?(stage), "Missing PIPELINE_TRANSITIONS entry for #{stage}"
    end
  end

  test "PIPELINE_STAGES constant matches enum keys" do
    assert_equal Task::PIPELINE_STAGES, Task.pipeline_stages.keys
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
