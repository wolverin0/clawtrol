class CreateWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows do |t|
      t.string :title, null: false
      t.boolean :active, null: false, default: false
      t.jsonb :definition, null: false, default: {}

      t.timestamps
    end
  end
end
