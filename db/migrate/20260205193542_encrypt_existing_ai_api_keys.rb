class EncryptExistingAiApiKeys < ActiveRecord::Migration[8.1]
  def up
    # Re-encrypt existing plaintext ai_api_key values using Rails encryption
    # Read raw values and write them back through the encrypted attribute
    User.find_each do |user|
      # Read the raw plaintext value directly from the database
      plaintext = ActiveRecord::Base.connection.select_value(
        "SELECT ai_api_key FROM users WHERE id = #{user.id}"
      )
      next if plaintext.blank?

      # Skip if already encrypted (encrypted values are JSON-like structures)
      next if plaintext.start_with?("{")

      # Write it back through the model, which will encrypt it
      user.update_column(:ai_api_key, nil) # Clear first to avoid decryption error
      user.reload
      user.update!(ai_api_key: plaintext)
    end
  end

  def down
    # Cannot reverse encryption without storing original values
    # This is a one-way migration for security
    raise ActiveRecord::IrreversibleMigration,
      "Cannot reverse encryption of ai_api_key values"
  end
end
