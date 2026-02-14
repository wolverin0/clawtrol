class CreateSwarmIdeas < ActiveRecord::Migration[8.0]
  def change
    create_table :swarm_ideas do |t|
      t.references :user, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :category
      t.string :suggested_model
      t.string :source
      t.string :project
      t.integer :estimated_minutes, default: 15
      t.string :icon, default: "🚀"
      t.string :difficulty
      t.string :pipeline_type
      t.boolean :enabled, default: true
      t.integer :times_launched, default: 0
      t.datetime :last_launched_at
      t.timestamps
    end

    add_index :swarm_ideas, [:user_id, :enabled]
    add_index :swarm_ideas, :category
  end
end
