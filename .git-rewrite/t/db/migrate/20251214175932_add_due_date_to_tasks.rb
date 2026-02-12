class AddDueDateToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :due_date, :date
  end
end
