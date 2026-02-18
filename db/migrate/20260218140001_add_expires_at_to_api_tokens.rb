class AddExpiresAtToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :expires_at, :datetime
    add_index :api_tokens, :expires_at
  end
end
