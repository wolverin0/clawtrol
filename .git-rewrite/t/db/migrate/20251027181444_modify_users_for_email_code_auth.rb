class ModifyUsersForEmailCodeAuth < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :password_digest, :string
    add_column :users, :verification_code, :string
    add_column :users, :code_expires_at, :datetime
  end
end
