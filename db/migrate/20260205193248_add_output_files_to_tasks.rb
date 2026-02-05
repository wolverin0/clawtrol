class AddOutputFilesToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :output_files, :jsonb, default: [], null: false
  end
end
