class CreateBackgroundRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :background_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: true, foreign_key: true
      t.references :openclaw_flow, null: true, foreign_key: true
      t.string :run_id, null: false                # OpenClaw's internal run/session ID
      t.string :run_type, null: false               # "cron", "subagent", "acp", "manual"
      t.string :status, default: "running"          # running, completed, failed, cancelled, timeout
      t.string :model                               # model used
      t.string :agent_id                            # openclaw agent id
      t.string :session_key                         # full session key
      t.string :label                               # human-readable label
      t.string :trigger                             # what triggered it (cron name, user, hook)
      t.text :error_message                         # error if failed
      t.text :summary                               # completion summary
      t.integer :tokens_in, default: 0
      t.integer :tokens_out, default: 0
      t.float :cost_usd                             # estimated cost
      t.integer :duration_seconds                   # how long it ran
      t.jsonb :metadata, default: {}                # extra data
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :background_runs, :run_id, unique: true
    add_index :background_runs, :run_type
    add_index :background_runs, :status
    add_index :background_runs, :session_key
    add_index :background_runs, [:user_id, :status]
    add_index :background_runs, :started_at
  end
end
