class AddProjectPathToBoards < ActiveRecord::Migration[8.1]
  def change
    add_column :boards, :project_path, :string
  end
end
