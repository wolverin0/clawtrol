require "test_helper"

class TaskTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid with minimum attributes" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one))
    assert task.valid?
  end

  test "requires name" do
    task = Task.new(name: "", board: boards(:one), user: users(:one))
    assert_not task.valid?
    assert_includes task.errors[:name], "can't be blank"
  end

  test "requires board" do
    task = Task.new(name: "Test", user: users(:one))
    assert_not task.valid?
    assert task.errors[:board].any?
  end

  test "requires user" do
    task = Task.new(name: "Test", board: boards(:one))
    assert_not task.valid?
    assert task.errors[:user].any?
  end

  test "defaults to inbox status" do
    task = Task.create!(name: "Default status", board: boards(:one), user: users(:one))
    assert_equal "inbox", task.status
  end

  test "defaults to none priority" do
    task = Task.create!(name: "Default priority", board: boards(:one), user: users(:one))
    assert_equal "none", task.priority
  end

  test "validates model inclusion" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one), model: "invalid_model")
    assert_not task.valid?
    assert task.errors[:model].any?
  end

  test "allows valid models" do
    Task::MODELS.each do |model_name|
      task = Task.new(name: "Test", board: boards(:one), user: users(:one), model: model_name)
      assert task.valid?, "Model '#{model_name}' should be valid"
    end
  end

  test "allows nil model" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one), model: nil)
    assert task.valid?
  end

  test "allows blank model" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one), model: "")
    assert task.valid?
  end

  test "validates status inclusion" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one))
    # Status enum raises ArgumentError for invalid values
    assert_raises(ArgumentError) { task.status = "nonexistent" }
  end

  test "validates priority inclusion" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one))
    assert_raises(ArgumentError) { task.priority = "critical" }
  end

  # --- Validation Command Security ---

  test "rejects validation command with shell metacharacters" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one),
                    validation_command: "bin/rails test; rm -rf /")
    assert_not task.valid?
    assert task.errors[:validation_command].any?
  end

  test "rejects validation command with pipe" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one),
                    validation_command: "cat /etc/passwd | grep root")
    assert_not task.valid?
  end

  test "rejects validation command with backticks" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one),
                    validation_command: "echo `whoami`")
    assert_not task.valid?
  end

  test "allows safe validation command" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one),
                    validation_command: "bin/rails test test/models/task_test.rb")
    assert task.valid?
  end

  # --- Associations ---

  test "belongs to user" do
    task = tasks(:one)
    assert_respond_to task, :user
    assert_equal users(:one), task.user
  end

  test "belongs to board" do
    task = tasks(:one)
    assert_respond_to task, :board
    assert_equal boards(:one), task.board
  end

  test "has many activities" do
    task = tasks(:one)
    assert_respond_to task, :activities
  end

  test "has many notifications" do
    task = tasks(:one)
    assert_respond_to task, :notifications
  end

  test "has many task_dependencies" do
    task = tasks(:one)
    assert_respond_to task, :task_dependencies
  end

  test "has many task_runs" do
    task = tasks(:one)
    assert_respond_to task, :task_runs
  end

  # --- Scopes ---

  test "not_archived excludes archived tasks" do
    board = boards(:one)
    user = users(:one)
    active_task = Task.create!(name: "Active", board: board, user: user, status: :inbox)
    archived_task = Task.create!(name: "Archived", board: board, user: user, status: :archived)

    results = board.tasks.not_archived
    assert_includes results, active_task
    assert_not_includes results, archived_task
  end

  test "errored scope returns tasks with error_at" do
    board = boards(:one)
    user = users(:one)
    errored = Task.create!(name: "Error", board: board, user: user)
    errored.update_columns(error_at: Time.current)
    normal = Task.create!(name: "Normal", board: board, user: user)

    assert_includes Task.errored, errored
    assert_not_includes Task.errored, normal
  end

  test "assigned_to_agent scope" do
    board = boards(:one)
    user = users(:one)
    assigned = Task.create!(name: "Assigned", board: board, user: user, assigned_to_agent: true, assigned_at: Time.current)
    unassigned = Task.create!(name: "Unassigned", board: board, user: user, assigned_to_agent: false)

    assert_includes Task.assigned_to_agent, assigned
    assert_not_includes Task.assigned_to_agent, unassigned
  end

  # --- Ordering ---

  test "ordered_for_column sorts in_review by updated_at desc then id desc" do
    board = boards(:one)
    user = users(:one)
    tied_time = Time.zone.parse("2026-02-08 10:00:00")

    older = Task.create!(name: "older", board: board, user: user, status: :in_review, updated_at: tied_time - 5.minutes)
    tie_low_id = Task.create!(name: "tie-low", board: board, user: user, status: :in_review)
    tie_high_id = Task.create!(name: "tie-high", board: board, user: user, status: :in_review)

    tie_low_id.update_columns(updated_at: tied_time)
    tie_high_id.update_columns(updated_at: tied_time)

    ordered_ids = board.tasks.in_review.ordered_for_column(:in_review).pluck(:id)

    assert_equal [tie_high_id.id, tie_low_id.id, older.id], ordered_ids.first(3)
  end

  test "ordered_for_column sorts done by id desc" do
    board = boards(:one)
    user = users(:one)

    t1 = Task.create!(name: "done-1", board: board, user: user, status: :done)
    t2 = Task.create!(name: "done-2", board: board, user: user, status: :done)
    t3 = Task.create!(name: "done-3", board: board, user: user, status: :done)

    t1.update_columns(completed_at: Time.zone.parse("2026-02-01 10:00:00"), updated_at: Time.zone.parse("2026-02-08 12:00:00"))
    t2.update_columns(completed_at: nil, updated_at: Time.zone.parse("2026-02-08 13:00:00"))
    t3.update_columns(completed_at: Time.zone.parse("2025-01-01 09:00:00"), updated_at: Time.zone.parse("2026-02-08 11:00:00"))

    ordered_ids = board.tasks.done.ordered_for_column(:done).pluck(:id)

    assert_equal [t3.id, t2.id, t1.id], ordered_ids.first(3)
  end

  # --- Auto-Claim ---

  test "try_auto_claim locks board to prevent concurrent claims" do
    board = boards(:one)
    user = users(:one)

    board.update_columns(auto_claim_enabled: true, last_auto_claim_at: nil)

    t1 = Task.create!(name: "auto-1", board: board, user: user, status: :inbox)
    t1.reload
    assert_equal "up_next", t1.status, "First task should be auto-claimed to up_next"
    assert t1.assigned_to_agent?, "First task should be assigned to agent"

    board.reload
    assert_not_nil board.last_auto_claim_at, "Board should record auto-claim timestamp"

    t2 = Task.create!(name: "auto-2", board: board, user: user, status: :inbox)
    t2.reload
    assert_equal "inbox", t2.status, "Second task should stay inbox (rate limited)"
    assert_not t2.assigned_to_agent?, "Second task should not be assigned"
  end

  test "try_auto_claim skips non-inbox tasks" do
    board = boards(:one)
    user = users(:one)
    board.update_columns(auto_claim_enabled: true, last_auto_claim_at: nil)

    task = Task.create!(name: "already progress", board: board, user: user, status: :up_next)
    task.reload
    assert_equal "up_next", task.status
  end

  # --- Runner Lease Requirement ---

  test "assigned tasks cannot move to in_progress without a runner lease" do
    board = boards(:one)
    user = users(:one)

    task = Task.create!(name: "lease required", board: board, user: user, status: :up_next, assigned_to_agent: true)

    task.status = :in_progress
    assert_not task.valid?
    assert_includes task.errors[:status].join(" "), "Runner Lease"
  end

  test "assigned tasks with linked session can move to in_progress" do
    board = boards(:one)
    user = users(:one)

    task = Task.create!(name: "with session", board: board, user: user, status: :up_next, assigned_to_agent: true)
    task.agent_session_id = "FAKE-SESSION"
    task.status = :in_progress
    assert task.valid?
  end

  # --- Model Aliases ---

  test "openclaw_spawn_model returns alias for gemini" do
    task = Task.new(model: "gemini")
    assert_equal "gemini3", task.openclaw_spawn_model
  end

  test "openclaw_spawn_model returns model as-is for opus" do
    task = Task.new(model: "opus")
    assert_equal "opus", task.openclaw_spawn_model
  end

  test "openclaw_spawn_model defaults to DEFAULT_MODEL when model is nil" do
    task = Task.new(model: nil)
    assert_equal Task::DEFAULT_MODEL, task.openclaw_spawn_model
  end

  test "openclaw_spawn_model defaults to DEFAULT_MODEL when model is blank" do
    task = Task.new(model: "")
    assert_equal Task::DEFAULT_MODEL, task.openclaw_spawn_model
  end

  # --- Pipeline Stage Transitions ---

  test "can set pipeline stage to classified from unstarted" do
    task = Task.create!(name: "Pipeline test", board: boards(:one), user: users(:one), pipeline_stage: :unstarted)
    task.pipeline_stage = :classified
    assert task.valid?
  end

  test "cannot skip pipeline stages" do
    task = Task.create!(name: "Pipeline skip", board: boards(:one), user: users(:one), pipeline_stage: :unstarted)
    task.pipeline_stage = :dispatched
    assert_not task.valid?
    assert task.errors[:pipeline_stage].any?
  end

  test "dispatched requires execution plan" do
    task = Task.create!(name: "No plan", board: boards(:one), user: users(:one), pipeline_stage: :unstarted)
    task.update_columns(pipeline_stage: Task.pipeline_stages[:planned]) # skip validations to set up state
    task.pipeline_stage = :dispatched
    assert_not task.valid?
    assert task.errors[:pipeline_stage].any?
  end

  test "dispatched with execution plan is valid" do
    task = Task.create!(name: "With plan", board: boards(:one), user: users(:one), pipeline_stage: :unstarted, execution_plan: "Step 1: do the thing")
    task.update_columns(pipeline_stage: Task.pipeline_stages[:planned])
    task.pipeline_stage = :dispatched
    assert task.valid?
  end

  # --- Constants ---

  test "MODELS contains expected models" do
    assert_includes Task::MODELS, "opus"
    assert_includes Task::MODELS, "codex"
    assert_includes Task::MODELS, "gemini"
    assert_includes Task::MODELS, "glm"
    assert_includes Task::MODELS, "sonnet"
  end

  test "DEFAULT_MODEL is opus" do
    assert_equal "opus", Task::DEFAULT_MODEL
  end

  # --- Optimistic Locking ---

  test "new tasks have lock_version 0" do
    task = Task.create!(name: "Lock test", board: boards(:one), user: users(:one))
    assert_equal 0, task.lock_version
  end

  test "lock_version increments on update" do
    task = Task.create!(name: "Lock test", board: boards(:one), user: users(:one))
    assert_equal 0, task.lock_version
    task.update!(name: "Updated name")
    assert_equal 1, task.lock_version
  end

  test "concurrent update raises StaleObjectError" do
    task = Task.create!(name: "Lock test", board: boards(:one), user: users(:one))

    # Load the same record into two separate instances
    task_a = Task.find(task.id)
    task_b = Task.find(task.id)

    # First update succeeds
    task_a.update!(name: "Update A")

    # Second update should fail — lock_version is stale
    assert_raises(ActiveRecord::StaleObjectError) do
      task_b.update!(name: "Update B")
    end
  end

  test "sequential updates work fine" do
    task = Task.create!(name: "Lock test", board: boards(:one), user: users(:one))
    task.update!(name: "First update")
    task.update!(name: "Second update")
    assert_equal 2, task.lock_version
    assert_equal "Second update", task.name
  end

  # --- Completion/Archival timestamp tracking ---

  test "sets completed_at when task becomes done" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), status: :inbox)
    assert_nil task.completed_at

    task.update!(status: :done)
    assert_not_nil task.completed_at
  end

  test "clears completed_at when task moves out of done" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), status: :inbox)
    task.update!(status: :done)
    assert_not_nil task.completed_at

    task.update!(status: :in_progress)
    assert_nil task.completed_at
  end

  test "sets archived_at when task becomes archived" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), status: :inbox)
    assert_nil task.archived_at

    task.update!(status: :archived)
    assert_not_nil task.archived_at
  end

  test "clears archived_at when task is unarchived" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), status: :inbox)
    task.update!(status: :archived)
    assert_not_nil task.archived_at

    task.update!(status: :inbox)
    assert_nil task.archived_at
  end

  test "clears archived_at when archived task moves to done" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), status: :inbox)
    task.update!(status: :archived)
    assert_not_nil task.archived_at

    task.update!(status: :done)
    assert_nil task.archived_at
    assert_not_nil task.completed_at
  end

  # --- Agent Integration: assign/unassign ---

  test "assign_to_agent! sets assigned_to_agent and assigned_at" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.assign_to_agent!
    assert task.assigned_to_agent?
    assert_not_nil task.assigned_at
  end

  test "unassign_from_agent! clears assignment" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.assign_to_agent!
    task.unassign_from_agent!
    assert_not task.assigned_to_agent?
    assert_nil task.assigned_at
  end

  # --- Agent Integration: error tracking ---

  test "set_error! records error message and timestamp" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.set_error!("Rate limit exceeded")
    assert_equal "Rate limit exceeded", task.error_message
    assert_not_nil task.error_at
    assert task.errored?
  end

  test "clear_error! removes error state" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.set_error!("Some error")
    task.clear_error!
    assert_nil task.error_message
    assert_nil task.error_at
    assert_not task.errored?
  end

  # --- Agent Integration: handoff ---

  test "handoff! changes model and resets state for retry" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), model: "opus", status: :inbox)
    task.handoff!(new_model: "sonnet")
    assert_equal "sonnet", task.model
  end

  # --- Agent Integration: retry ---

  test "increment_retry! increases retry_count" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    assert_equal 0, task.retry_count
    task.increment_retry!
    assert_equal 1, task.retry_count
  end

  test "max_retries_exceeded? returns false when under limit" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), retry_count: 0)
    assert_not task.max_retries_exceeded?
  end

  test "max_retries_exceeded? returns true at limit" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), retry_count: 3)
    assert task.max_retries_exceeded?
  end

  # --- Agent Integration: review lifecycle ---

  test "start_review! sets review fields" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.start_review!(type: "command", config: { command: "bin/rails test" })
    assert_equal "command", task.review_type
    assert_equal "pending", task.review_status
    assert_equal({ "command" => "bin/rails test" }, task.review_config)
  end

  test "complete_review! sets status and result" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one), status: :in_review)
    task.start_review!(type: "command", config: {})
    task.complete_review!(status: "passed", result: { summary: "All tests pass" })
    assert_equal "passed", task.review_status
    assert_equal "All tests pass", task.review_result["summary"]
    assert task.review_result["completed_at"].present?
  end

  test "review_in_progress? returns true when running" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.update!(review_status: "running", review_type: "command")
    assert task.review_in_progress?
  end

  test "command_review? returns true for command type" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.update!(review_type: "command")
    assert task.command_review?
    assert_not task.debate_review?
  end

  test "debate_review? returns true for debate type" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    task.update!(review_type: "debate")
    assert task.debate_review?
    assert_not task.command_review?
  end

  # --- Agent Integration: followup ---

  test "create_followup_task! creates linked task" do
    task = Task.create!(name: "Original", board: boards(:one), user: users(:one))
    followup = task.create_followup_task!(followup_name: "Fix: Original")
    assert followup.persisted?
    assert_equal "Fix: Original", followup.name
    assert_equal task.board_id, followup.board_id
    assert_equal task.user_id, followup.user_id
  end

  test "followup_task? returns true when task has a parent" do
    parent = Task.create!(name: "Original", board: boards(:one), user: users(:one))
    followup = parent.create_followup_task!(followup_name: "Followup")
    assert followup.followup_task?
    assert_not parent.followup_task?
  end

  # --- Agent Integration: runner lease queries ---

  test "runner_lease_active? with active lease" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    RunnerLease.create_for_task!(task: task, agent_name: "Otacon", source: "test")
    assert task.runner_lease_active?
  end

  test "runner_lease_active? without lease" do
    task = Task.create!(name: "Test", board: boards(:one), user: users(:one))
    assert_not task.runner_lease_active?
  end
end
