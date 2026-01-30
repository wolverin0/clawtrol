class CreateTaskLists < ActiveRecord::Migration[8.1]
  def change
    create_table :task_lists do |t|
      t.string :title
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end

    add_index :task_lists, :position
    # Partial unique index that only applies to non-null positions
    add_index :task_lists, [ :project_id, :position ], unique: true, where: "position IS NOT NULL"
  end
end
