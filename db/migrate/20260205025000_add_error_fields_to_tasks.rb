class AddErrorFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :error_message, :text
    add_column :tasks, :error_at, :datetime
    add_index :tasks, :error_at, where: "error_at IS NOT NULL"
  end
end
