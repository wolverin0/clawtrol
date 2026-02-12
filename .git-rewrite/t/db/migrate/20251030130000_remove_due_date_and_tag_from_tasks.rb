class RemoveDueDateAndTagFromTasks < ActiveRecord::Migration[8.1]
  def change
    # Use safety options to avoid errors if columns are missing in some envs
    if column_exists?(:tasks, :due_date)
      remove_column :tasks, :due_date, :date
    end
    if column_exists?(:tasks, :tag)
      remove_column :tasks, :tag, :string
    end
  end
end
