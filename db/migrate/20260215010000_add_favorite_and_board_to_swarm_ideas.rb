class AddFavoriteAndBoardToSwarmIdeas < ActiveRecord::Migration[8.1]
  def change
    add_column :swarm_ideas, :favorite, :boolean, default: false, null: false
    add_column :swarm_ideas, :board_id, :integer, default: nil
    add_index :swarm_ideas, [:user_id, :favorite]
  end
end
