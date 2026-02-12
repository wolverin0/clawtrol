class AddAgentLastActiveAtToUsersAndRemoveDefaults < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agent_last_active_at, :datetime

    # Remove defaults so nil indicates "no agent connected yet"
    change_column_default :users, :agent_name, from: "OpenClaw", to: nil
    change_column_default :users, :agent_emoji, from: "🦞", to: nil

    # Clear existing default values (optional - keeps them if agent has connected)
    # Uncomment if you want to reset all users:
    # User.update_all(agent_name: nil, agent_emoji: nil)
  end
end
