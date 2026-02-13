class AddOriginFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :origin_chat_id, :string
    add_column :tasks, :origin_thread_id, :integer
  end
end
