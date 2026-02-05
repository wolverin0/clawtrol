class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, foreign_key: true  # Optional - some notifications may not be task-related
      t.string :event_type, null: false
      t.text :message, null: false
      t.datetime :read_at

      t.timestamps
    end

    # Index for efficient unread count queries
    add_index :notifications, [:user_id, :read_at], name: "index_notifications_on_user_unread"
    add_index :notifications, [:user_id, :created_at], order: { created_at: :desc }
    add_index :notifications, :event_type
  end
end
