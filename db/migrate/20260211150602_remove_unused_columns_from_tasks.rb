class RemoveUnusedColumnsFromTasks < ActiveRecord::Migration[8.1]
  def change
    remove_column :tasks, :reach, :integer
    remove_column :tasks, :impact, :integer
    remove_column :tasks, :effort, :integer
    remove_column :tasks, :confidence, :integer
    remove_column :tasks, :original_position, :integer
  end
end
