class CreateTaskRunsAndAutoPullGuardrails < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :task_runs do |t|
      t.references :task, null: false, foreign_key: true

      # Idempotency key provided by OpenClaw
      t.uuid :run_id, null: false
      t.integer :run_number, null: false

      t.datetime :ended_at
      t.boolean :needs_follow_up, null: false, default: false
      t.string :recommended_action, null: false, default: "in_review"

      t.text :summary
      t.jsonb :achieved, null: false, default: []
      t.jsonb :evidence, null: false, default: []
      t.jsonb :remaining, null: false, default: []
      t.text :next_prompt

      t.string :model_used
      t.string :openclaw_session_id
      t.string :openclaw_session_key

      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :task_runs, :run_id, unique: true
    add_index :task_runs, [ :task_id, :run_number ], unique: true

    change_table :tasks do |t|
      t.integer :run_count, null: false, default: 0
      t.uuid :last_run_id
      t.datetime :last_outcome_at
      t.boolean :last_needs_follow_up
      t.string :last_recommended_action

      # Auto-pull circuit breaker
      t.integer :auto_pull_failures, null: false, default: 0
      t.boolean :auto_pull_blocked, null: false, default: false
      t.datetime :auto_pull_last_attempt_at
      t.datetime :auto_pull_last_error_at
      t.text :auto_pull_last_error
    end

    add_index :tasks, :auto_pull_blocked
  end
end
