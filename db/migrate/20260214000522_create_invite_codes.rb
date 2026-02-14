class CreateInviteCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :invite_codes do |t|
      t.string :code, null: false
      t.string :email
      t.datetime :used_at
      t.bigint :created_by_id, index: true

      t.timestamps
    end
    add_index :invite_codes, :code, unique: true
    add_foreign_key :invite_codes, :users, column: :created_by_id
  end
end
