class CreateBrainDumps < ActiveRecord::Migration[8.1]
  def change
    create_table :brain_dumps do |t|
      t.text :content, null: false
      t.boolean :processed, default: false, null: false
      t.jsonb :metadata, default: {}, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :brain_dumps, :processed
  end
end
