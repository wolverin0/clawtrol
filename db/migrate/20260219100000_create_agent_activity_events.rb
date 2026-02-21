# frozen_string_literal: true

class CreateAgentActivityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_activity_events do |t|
      t.references :task, null: false, foreign_key: true
      t.string :run_id, null: false
      t.string :source, null: false, default: "orchestrator"
      t.string :level, null: false, default: "info"
      t.string :event_type, null: false
      t.text :message
      t.jsonb :payload, null: false, default: {}
      t.bigint :seq, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :agent_activity_events, [:task_id, :created_at], name: "idx_agent_activity_events_task_created"
    add_index :agent_activity_events, [:run_id, :seq], unique: true, name: "idx_agent_activity_events_run_seq"
  end
end
