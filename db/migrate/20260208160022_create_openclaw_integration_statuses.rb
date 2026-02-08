class CreateOpenclawIntegrationStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :openclaw_integration_statuses do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # 0 = unknown, 1 = ok, 2 = degraded, 3 = down
      t.integer :memory_search_status, null: false, default: 0
      t.datetime :memory_search_last_checked_at
      t.text :memory_search_last_error
      t.datetime :memory_search_last_error_at

      t.timestamps
    end
  end
end
