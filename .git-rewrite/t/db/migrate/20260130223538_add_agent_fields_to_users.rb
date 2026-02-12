class AddAgentFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agent_name, :string, default: "Assistant"
    add_column :users, :agent_emoji, :string, default: "🤖"
  end
end
