class ChangeTaskListIdNullableOnTasks < ActiveRecord::Migration[8.1]
  def change
    change_column_null :tasks, :task_list_id, true
  end
end
