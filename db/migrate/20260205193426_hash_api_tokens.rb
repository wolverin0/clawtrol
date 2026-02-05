class HashApiTokens < ActiveRecord::Migration[8.1]
  def up
    # Add new columns for hashed token storage
    add_column :api_tokens, :token_digest, :string
    add_column :api_tokens, :token_prefix, :string, limit: 8

    # Migrate existing plaintext tokens to hashed versions
    ApiToken.reset_column_information
    ApiToken.find_each do |api_token|
      plaintext = api_token.read_attribute(:token)
      next if plaintext.blank?

      digest = Digest::SHA256.hexdigest(plaintext)
      prefix = plaintext[0..7]
      api_token.update_columns(token_digest: digest, token_prefix: prefix)
    end

    # Remove old plaintext token column and add proper index
    remove_index :api_tokens, :token, if_exists: true
    remove_column :api_tokens, :token
    add_index :api_tokens, :token_digest, unique: true

    change_column_null :api_tokens, :token_digest, false
  end

  def down
    add_column :api_tokens, :token, :string
    remove_index :api_tokens, :token_digest, if_exists: true
    remove_column :api_tokens, :token_digest
    remove_column :api_tokens, :token_prefix
    add_index :api_tokens, :token, unique: true
  end
end
