class AddTaskListIdToTasks < ActiveRecord::Migration[8.1]
  def up
    # Add the column as nullable first
    add_reference :tasks, :task_list, null: true, foreign_key: true

    # Create default task lists for existing projects and associate tasks
    Project.find_each do |project|
      task_list = project.task_lists.create!(
        title: "Tasks",
        user_id: project.user_id,
        position: 1
      )
      project.tasks.update_all(task_list_id: task_list.id)
    end

    # Now make it non-nullable
    change_column_null :tasks, :task_list_id, false
  end

  def down
    remove_reference :tasks, :task_list, foreign_key: true
  end
end
