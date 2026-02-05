class CreateTaskTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :task_templates do |t|
      t.string :name, null: false
      t.text :description_template
      t.string :model
      t.integer :priority, default: 0
      t.string :validation_command
      t.string :icon
      t.string :slug, null: false
      t.boolean :global, default: false
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :task_templates, :slug
    add_index :task_templates, [:user_id, :slug], unique: true, where: "user_id IS NOT NULL"
    add_index :task_templates, :slug, unique: true, where: "global = true", name: "index_task_templates_on_slug_global"
  end
end
