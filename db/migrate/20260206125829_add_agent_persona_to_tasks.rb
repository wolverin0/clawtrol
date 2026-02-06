class AddAgentPersonaToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :agent_persona, null: true, foreign_key: true
  end
end
