class AddOauthAndPasswordToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :password_digest, :string
    remove_column :users, :verification_code, :string
    remove_column :users, :code_expires_at, :datetime
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
  end
end
