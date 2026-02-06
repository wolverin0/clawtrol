class CreateAgentPersonas < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_personas do |t|
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :role
      t.text :description
      t.string :model, default: 'sonnet'
      t.string :fallback_model
      t.string :tier  # strategic-reasoning, fast-coding, research, operations
      t.string :project  # global or project code
      t.string :emoji, default: '🤖'
      t.text :tools, array: true, default: []
      t.text :system_prompt
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :agent_personas, [:user_id, :name], unique: true
  end
end
