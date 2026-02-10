class AddOpenclawHooksTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :openclaw_hooks_token, :string
  end
end