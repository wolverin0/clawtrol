class CreateAuditReports < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_type, null: false
      t.decimal :overall_score, precision: 4, scale: 1, null: false
      t.jsonb :scores, default: {}
      t.jsonb :anti_pattern_counts, default: {}
      t.jsonb :worst_moments, default: []
      t.integer :session_files_analyzed, default: 0
      t.integer :messages_analyzed, default: 0
      t.string :report_path

      t.timestamps
    end

    add_index :audit_reports, [:user_id, :report_type, :created_at]
  end
end
