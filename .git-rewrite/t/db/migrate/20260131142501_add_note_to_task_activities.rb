class AddNoteToTaskActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :task_activities, :note, :text
  end
end
