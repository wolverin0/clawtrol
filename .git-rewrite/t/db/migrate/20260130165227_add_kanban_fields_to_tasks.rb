class AddKanbanFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :status, :integer, default: 0, null: false
    add_column :tasks, :blocked, :boolean, default: false, null: false
    add_column :tasks, :tags, :string, array: true, default: []
    add_column :tasks, :comments_count, :integer, default: 0, null: false

    add_index :tasks, :status
    add_index :tasks, :blocked

    # Make project_id optional for backward compatibility
    change_column_null :tasks, :project_id, true
  end
end
