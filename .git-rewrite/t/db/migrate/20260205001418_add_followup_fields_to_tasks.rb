class AddFollowupFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :suggested_followup, :text
    add_column :tasks, :followup_task_id, :bigint
    add_index :tasks, :followup_task_id
    add_foreign_key :tasks, :tasks, column: :followup_task_id, on_delete: :nullify
  end
end
