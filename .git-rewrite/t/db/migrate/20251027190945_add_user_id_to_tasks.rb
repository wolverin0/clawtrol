class AddUserIdToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :user, null: true, foreign_key: true
  end
end
