class CreateSavedLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url
      t.string :title
      t.string :source_type
      t.integer :status
      t.text :summary
      t.text :raw_content
      t.datetime :processed_at
      t.string :error_message

      t.timestamps
    end
  end
end
