class CreateFactoryLoopAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :factory_loop_agents do |t|
      t.references :factory_loop, null: false, foreign_key: true
      t.references :factory_agent, null: false, foreign_key: true
      t.boolean :enabled, default: true
      t.integer :cooldown_hours_override
      t.integer :confidence_threshold_override
      t.timestamps
    end

    add_index :factory_loop_agents, [:factory_loop_id, :factory_agent_id], unique: true, name: "idx_loop_agents_unique"
  end
end
