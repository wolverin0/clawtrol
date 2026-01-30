class MergeTaskListsPerProject < ActiveRecord::Migration[8.1]
  def up
    # Merge multiple task lists into one per project
    execute <<-SQL
      WITH ranked_lists AS (
        SELECT id, project_id,
               ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY position ASC, id ASC) as rn
        FROM task_lists
      ),
      primary_lists AS (
        SELECT id, project_id FROM ranked_lists WHERE rn = 1
      ),
      secondary_lists AS (
        SELECT id, project_id FROM ranked_lists WHERE rn > 1
      )
      UPDATE tasks
      SET task_list_id = (
        SELECT pl.id FROM primary_lists pl WHERE pl.project_id = tasks.project_id
      ),
      position = (
        SELECT COALESCE(MAX(t2.position), 0) + tasks.position
        FROM tasks t2
        WHERE t2.task_list_id = (
          SELECT pl.id FROM primary_lists pl WHERE pl.project_id = tasks.project_id
        )
      )
      WHERE task_list_id IN (SELECT id FROM secondary_lists)
    SQL

    # Delete extra task lists (keep only the first one per project)
    execute <<-SQL
      DELETE FROM task_lists
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY position ASC, id ASC) as rn
          FROM task_lists
        ) ranked
        WHERE rn > 1
      )
    SQL

    # Remove the unique index on project_id and position
    remove_index :task_lists, name: "index_task_lists_on_project_id_and_position", if_exists: true

    # Remove the color column
    remove_column :task_lists, :color
  end

  def down
    # Re-add color column with default
    add_column :task_lists, :color, :string, default: "gray"

    # Re-add unique index
    add_index :task_lists, [:project_id, :position],
              unique: true,
              where: "(\"position\" IS NOT NULL)",
              name: "index_task_lists_on_project_id_and_position"
  end
end
