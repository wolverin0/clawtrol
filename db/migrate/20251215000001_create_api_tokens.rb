class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.string :token, null: false
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
  end
end
