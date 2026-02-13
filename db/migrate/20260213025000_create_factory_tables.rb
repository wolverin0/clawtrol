class CreateFactoryTables < ActiveRecord::Migration[8.1]
  def change
    create_table :factory_loops do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :icon, default: "🏭"
      t.string :status, null: false, default: "idle" # idle, playing, paused, stopped, error
      t.integer :interval_ms, null: false
      t.string :model, null: false
      t.string :fallback_model
      t.text :system_prompt
      t.jsonb :state, null: false, default: {}
      t.jsonb :config, null: false, default: {}
      t.jsonb :metrics, null: false, default: {}
      t.string :openclaw_cron_id
      t.string :openclaw_session_key
      t.datetime :last_cycle_at
      t.datetime :last_error_at
      t.text :last_error_message
      t.integer :total_cycles, default: 0
      t.integer :total_errors, default: 0
      t.integer :avg_cycle_duration_ms

      t.timestamps
    end

    add_index :factory_loops, :slug, unique: true
    add_index :factory_loops, :status
    add_index :factory_loops, :openclaw_cron_id, unique: true, where: "openclaw_cron_id IS NOT NULL"

    create_table :factory_cycle_logs do |t|
      t.references :factory_loop, null: false, foreign_key: true
      t.integer :cycle_number, null: false
      t.string :status, null: false, default: "running" # running, completed, failed, skipped
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :duration_ms
      t.string :model_used
      t.integer :input_tokens
      t.integer :output_tokens
      t.jsonb :state_before
      t.jsonb :state_after
      t.text :summary
      t.jsonb :actions_taken, default: []
      t.jsonb :errors, default: []

      t.datetime :created_at, null: false
    end

    add_index :factory_cycle_logs, [ :factory_loop_id, :cycle_number ], unique: true, name: "idx_cycle_logs_loop_cycle"
    add_index :factory_cycle_logs, [ :factory_loop_id, :created_at ], order: { created_at: :desc }, name: "idx_cycle_logs_loop_recent"
    add_index :factory_cycle_logs, :status
  end
end
