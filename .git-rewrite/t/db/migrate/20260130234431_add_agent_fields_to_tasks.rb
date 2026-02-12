class AddAgentFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :agent_claimed_at, :datetime
  end
end
