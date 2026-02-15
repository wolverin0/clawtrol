# frozen_string_literal: true

# Adds a counter cache column for tasks on boards.
# Eliminates COUNT(*) queries when displaying boards list.
class AddTasksCountToBoards < ActiveRecord::Migration[8.0]
  def up
    add_column :boards, :tasks_count, :integer, default: 0, null: false

    # Populate existing counts
    execute <<~SQL
      UPDATE boards
      SET tasks_count = (
        SELECT COUNT(*)
        FROM tasks
        WHERE tasks.board_id = boards.id
      )
    SQL
  end

  def down
    remove_column :boards, :tasks_count
  end
end
