class AddAutoRetrySettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :auto_retry_enabled, :boolean, default: false
    add_column :users, :auto_retry_max, :integer, default: 3
    add_column :users, :auto_retry_backoff, :string, default: "1min"
    add_column :users, :fallback_model_chain, :string
  end
end
