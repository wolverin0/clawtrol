class AddTasksCountToAgentPersonas < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_personas, :tasks_count, :integer, default: 0
  end
end
