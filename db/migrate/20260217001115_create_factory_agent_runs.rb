class CreateFactoryAgentRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :factory_agent_runs do |t|
      t.references :factory_loop, null: false, foreign_key: true
      t.references :factory_agent, null: false, foreign_key: true
      t.references :factory_cycle_log, foreign_key: true
      t.string :status # "clean" | "findings" | "error"
      t.string :commit_sha
      t.integer :findings_count, default: 0
      t.integer :items_generated, default: 0
      t.jsonb :findings, default: []
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :tokens_used
      t.timestamps
    end

    add_index :factory_agent_runs, [:factory_loop_id, :factory_agent_id, :created_at], name: "idx_agent_runs_loop_agent_created"
    add_index :factory_agent_runs, :status
  end
end
