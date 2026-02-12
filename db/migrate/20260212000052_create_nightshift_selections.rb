class CreateNightshiftSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :nightshift_selections do |t|
      t.integer :mission_id, null: false
      t.string :title, null: false
      t.boolean :enabled, default: true, null: false
      t.date :scheduled_date, null: false
      t.string :status, default: "pending", null: false
      t.datetime :launched_at
      t.datetime :completed_at
      t.text :result

      t.timestamps
    end
    add_index :nightshift_selections, [:mission_id, :scheduled_date], unique: true
  end
end
