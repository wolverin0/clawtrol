# frozen_string_literal: true

class AddEventDedupToWebhookLogs < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:webhook_logs, :event_id)
      add_column :webhook_logs, :event_id, :string
    end

    # Allow webhook idempotency rows to exist without a user context
    # (incoming service-to-service hooks are not always tied to a user).
    change_column_null :webhook_logs, :user_id, true

    unless index_exists?(:webhook_logs, [:endpoint, :event_id], unique: true, name: 'idx_webhook_logs_on_endpoint_event_id_unique')
      add_index :webhook_logs,
                [:endpoint, :event_id],
                unique: true,
                where: 'event_id IS NOT NULL',
                name: 'idx_webhook_logs_on_endpoint_event_id_unique'
    end
  end
end
