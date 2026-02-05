class AddCompositeIndexesToTasks < ActiveRecord::Migration[8.1]
  def change
    add_index :tasks, [:board_id, :status, :position], name: "index_tasks_on_board_status_position"
    add_index :tasks, [:user_id, :status], name: "index_tasks_on_user_status"
    add_index :tasks, [:user_id, :assigned_to_agent, :status], name: "index_tasks_on_user_agent_status"
  end
end
