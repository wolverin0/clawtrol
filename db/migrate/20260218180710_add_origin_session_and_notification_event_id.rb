# frozen_string_literal: true

class AddOriginSessionAndNotificationEventId < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :origin_session_id, :string
    add_column :tasks, :origin_session_key, :string

    add_column :notifications, :event_id, :string
    add_index :notifications, :event_id
  end
end
