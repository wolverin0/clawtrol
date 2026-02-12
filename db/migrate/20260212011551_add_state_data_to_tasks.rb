class AddStateDataToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :state_data, :jsonb, default: {}, null: false
  end
end
