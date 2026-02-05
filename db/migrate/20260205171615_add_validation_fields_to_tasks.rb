class AddValidationFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :validation_command, :string
    add_column :tasks, :validation_status, :string  # pending/passed/failed
    add_column :tasks, :validation_output, :text
    add_index :tasks, :validation_status, where: "validation_status IS NOT NULL"
  end
end
