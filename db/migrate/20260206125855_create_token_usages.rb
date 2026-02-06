class CreateTokenUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :token_usages do |t|
      t.references :task, foreign_key: true, null: false
      t.references :agent_persona, foreign_key: true, null: true
      t.string :model
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0
      t.string :session_key
      t.timestamps
    end

    add_index :token_usages, :model
    add_index :token_usages, :created_at
    add_index :token_usages, :session_key
  end
end
