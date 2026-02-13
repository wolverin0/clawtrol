class AddMissingIndexesToTasks < ActiveRecord::Migration[8.0]
  def change
    add_index :tasks, :agent_session_id, where: "agent_session_id IS NOT NULL", name: "index_tasks_on_agent_session_id_partial"
    add_index :tasks, :agent_session_key, where: "agent_session_key IS NOT NULL", name: "index_tasks_on_agent_session_key_partial"
  end
end
