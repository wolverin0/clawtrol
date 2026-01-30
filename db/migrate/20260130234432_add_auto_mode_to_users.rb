class AddAutoModeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agent_auto_mode, :boolean, default: true, null: false
  end
end
