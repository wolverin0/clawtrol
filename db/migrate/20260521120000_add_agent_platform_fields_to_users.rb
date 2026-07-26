class AddAgentPlatformFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_agent_platform, :string, default: "openclaw", null: false
    add_column :users, :hermes_gateway_url, :string
    add_column :users, :hermes_gateway_token, :string
    add_column :users, :hermes_hooks_token, :string
    add_column :users, :hermes_home, :string, default: "~/.hermes", null: false
    add_column :users, :hermes_profile, :string
  end
end
