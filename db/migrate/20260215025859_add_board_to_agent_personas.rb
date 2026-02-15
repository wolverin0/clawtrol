class AddBoardToAgentPersonas < ActiveRecord::Migration[8.1]
  def change
    add_reference :agent_personas, :board, null: true, foreign_key: true
    add_column :agent_personas, :auto_generated, :boolean, default: false
  end
end
