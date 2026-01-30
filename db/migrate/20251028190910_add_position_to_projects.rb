class AddPositionToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :position, :integer
    add_index :projects, :position
    add_index :projects, [ :user_id, :position ], unique: true
  end
end
