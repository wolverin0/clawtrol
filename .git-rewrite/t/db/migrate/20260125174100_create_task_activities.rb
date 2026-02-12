class CreateTaskActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :task_activities do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :action, null: false  # created, updated, completed, uncompleted
      t.string :field_name           # priority, due_date, name, description
      t.string :old_value
      t.string :new_value
      t.string :source, default: "web"  # web, api

      t.timestamps
    end

    add_index :task_activities, [:task_id, :created_at]
  end
end
