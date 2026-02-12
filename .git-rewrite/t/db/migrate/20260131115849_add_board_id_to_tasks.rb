class AddBoardIdToTasks < ActiveRecord::Migration[8.1]
  def change
    # Add board_id column (nullable first for migration)
    add_reference :tasks, :board, null: true, foreign_key: true

    # Create default boards for existing users and assign their tasks
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO boards (name, icon, color, user_id, position, created_at, updated_at)
          SELECT 'Personal', '📋', 'gray', id, 1, NOW(), NOW()
          FROM users
          WHERE NOT EXISTS (SELECT 1 FROM boards WHERE boards.user_id = users.id);
        SQL

        execute <<-SQL
          UPDATE tasks
          SET board_id = (
            SELECT boards.id FROM boards WHERE boards.user_id = tasks.user_id LIMIT 1
          )
          WHERE board_id IS NULL;
        SQL
      end
    end

    # Now make board_id required
    change_column_null :tasks, :board_id, false
  end
end
