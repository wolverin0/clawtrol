class AddAgentWebhookUrlToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agent_webhook_url, :string
  end
end
