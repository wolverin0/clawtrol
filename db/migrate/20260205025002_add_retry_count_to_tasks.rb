class AddRetryCountToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :retry_count, :integer, default: 0 unless column_exists?(:tasks, :retry_count)
  end
end
