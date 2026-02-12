class AddNightlyFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :nightly, :boolean, default: false, null: false
    add_column :tasks, :nightly_delay_hours, :integer
    add_index :tasks, :nightly
  end
end
