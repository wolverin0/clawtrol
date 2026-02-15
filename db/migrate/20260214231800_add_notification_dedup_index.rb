# frozen_string_literal: true

# Optimize the Notification.create_deduped! query which checks:
#   WHERE user_id = ? AND event_type = ? AND task_id = ? AND created_at >= ?
# This composite index covers the most common dedup lookup path.
class AddNotificationDedupIndex < ActiveRecord::Migration[8.0]
  def change
    unless index_exists?(:notifications, [:user_id, :event_type, :created_at], name: "index_notifications_on_dedup")
      add_index :notifications, [:user_id, :event_type, :created_at],
        name: "index_notifications_on_dedup",
        order: { created_at: :desc }
    end
  end
end
