class AddOriginalPositionToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :original_position, :integer
  end
end
