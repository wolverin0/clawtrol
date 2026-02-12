class AddPositionToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :position, :integer
    add_index :tasks, :position

    # Set initial positions for existing tasks
    reversible do |dir|
      dir.up do
        # Group tasks by project and assign positions
        execute <<-SQL
          UPDATE tasks
          SET position = (
            SELECT COUNT(*)
            FROM tasks AS t2
            WHERE t2.project_id = tasks.project_id
            AND t2.id <= tasks.id
          )
        SQL
      end
    end
  end
end
