class CreateNightshiftMissions < ActiveRecord::Migration[8.0]
  def change
    create_table :nightshift_missions do |t|
      t.string :name, null: false
      t.text :description
      t.string :icon, default: "🔧"
      t.string :model, default: "gemini"
      t.integer :estimated_minutes, default: 30
      t.string :frequency, default: "manual"
      t.jsonb :days_of_week, default: []
      t.boolean :enabled, default: true
      t.datetime :last_run_at
      t.string :created_by, default: "user"
      t.string :category, default: "general"
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :nightshift_missions, :frequency
    add_index :nightshift_missions, :enabled
    add_index :nightshift_missions, :category

    # Update nightshift_selections to reference nightshift_missions
    add_reference :nightshift_selections, :nightshift_mission, foreign_key: true, null: true
  end
end
