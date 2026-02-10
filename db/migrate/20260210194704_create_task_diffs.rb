class CreateTaskDiffs < ActiveRecord::Migration[8.1]
  def change
    create_table :task_diffs do |t|
      t.references :task, null: false, foreign_key: true
      t.string :file_path, null: false
      t.text :diff_content
      t.string :diff_type, default: "modified" # modified, added, deleted

      t.timestamps
    end

    add_index :task_diffs, [:task_id, :file_path], unique: true
  end
end
