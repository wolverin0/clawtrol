class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :task, null: false, foreign_key: true
      t.string :author_type
      t.string :author_name
      t.text :body

      t.timestamps
    end
  end
end
