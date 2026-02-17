class CreateFactoryAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :factory_agents do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category
      t.string :source # "voltagent" | "anthropic" | "custom"
      t.text :system_prompt, null: false
      t.text :description
      t.jsonb :tools_needed, default: []
      t.string :run_condition, default: "new_commits" # new_commits/daily/weekly/always
      t.integer :cooldown_hours, default: 24
      t.integer :default_confidence_threshold, default: 80
      t.integer :priority, default: 5
      t.boolean :builtin, default: false
      t.timestamps
    end

    add_index :factory_agents, :slug, unique: true
    add_index :factory_agents, :category
    add_index :factory_agents, :builtin
  end
end
