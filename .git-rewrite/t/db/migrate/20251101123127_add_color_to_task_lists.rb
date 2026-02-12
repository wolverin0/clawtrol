class AddColorToTaskLists < ActiveRecord::Migration[8.1]
  def up
    add_column :task_lists, :color, :string, default: "gray"
    # Set default color for existing records
    execute "UPDATE task_lists SET color = 'gray' WHERE color IS NULL" if table_exists?(:task_lists)
  end

  def down
    remove_column :task_lists, :color
  end
end
