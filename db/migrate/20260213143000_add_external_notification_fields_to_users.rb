class AddExternalNotificationFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :telegram_bot_token, :string
    add_column :users, :telegram_chat_id, :string
    add_column :users, :webhook_notification_url, :string
    add_column :users, :notifications_enabled, :boolean, default: true, null: false
  end
end
