class CreateBehavioralInterventions < ActiveRecord::Migration[8.1]
  def change
    create_table :behavioral_interventions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :audit_report, null: true, foreign_key: true
      t.text :rule, null: false
      t.string :category, null: false
      t.decimal :baseline_score, precision: 4, scale: 1
      t.decimal :current_score, precision: 4, scale: 1
      t.string :status, null: false, default: "active"
      t.datetime :resolved_at
      t.datetime :regressed_at
      t.text :notes

      t.timestamps
    end

    add_index :behavioral_interventions, [:user_id, :status]
  end
end
