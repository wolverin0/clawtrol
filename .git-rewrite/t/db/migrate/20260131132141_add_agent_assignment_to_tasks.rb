class AddAgentAssignmentToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :assigned_to_agent, :boolean, default: false, null: false
    add_column :tasks, :assigned_at, :datetime
    add_index :tasks, :assigned_to_agent
  end
end
