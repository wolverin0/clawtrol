class AddFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :description, :text
    add_column :tasks, :due_date, :date
    add_column :tasks, :tag, :string
  end
end
