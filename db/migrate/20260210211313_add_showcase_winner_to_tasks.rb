class AddShowcaseWinnerToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :showcase_winner, :boolean, default: false, null: false
  end
end
