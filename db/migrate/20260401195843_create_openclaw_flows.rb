class CreateOpenclawFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :openclaw_flows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: true, foreign_key: true
      t.string :flow_id, null: false
      t.string :flow_type
      t.string :status, default: "active"
      t.string :blocked_reason
      t.string :model
      t.string :agent_id
      t.string :session_key
      t.string :parent_session_key
      t.integer :child_count, default: 0
      t.integer :completed_count, default: 0
      t.jsonb :metadata, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :last_sync_at
      t.timestamps
    end
    add_index :openclaw_flows, :flow_id, unique: true
    add_index :openclaw_flows, :status
    add_index :openclaw_flows, :session_key
    add_reference :tasks, :openclaw_flow, foreign_key: true, null: true
  end
end
