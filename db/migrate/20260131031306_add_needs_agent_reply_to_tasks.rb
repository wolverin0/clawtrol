class AddNeedsAgentReplyToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :needs_agent_reply, :boolean, default: false, null: false
    add_index :tasks, :needs_agent_reply
  end
end
