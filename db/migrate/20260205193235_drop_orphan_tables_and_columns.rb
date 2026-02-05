class DropOrphanTablesAndColumns < ActiveRecord::Migration[8.1]
  def up
    # Remove FK constraints from tasks first
    remove_foreign_key :tasks, :projects, if_exists: true
    remove_foreign_key :tasks, :task_lists, if_exists: true

    # Remove FK constraints on dependent tables
    remove_foreign_key :tags, :projects, if_exists: true
    remove_foreign_key :tags, :users, if_exists: true
    remove_foreign_key :task_lists, :projects, if_exists: true
    remove_foreign_key :task_lists, :users, if_exists: true
    remove_foreign_key :task_tags, :tags, if_exists: true
    remove_foreign_key :task_tags, :tasks, if_exists: true

    # Remove orphan columns from tasks
    remove_index :tasks, :project_id, if_exists: true
    remove_index :tasks, :task_list_id, if_exists: true
    remove_column :tasks, :project_id, :integer
    remove_column :tasks, :task_list_id, :bigint

    # Drop orphan tables
    drop_table :task_tags, if_exists: true
    drop_table :tags, if_exists: true
    drop_table :task_lists, if_exists: true
    drop_table :projects, if_exists: true
  end

  def down
    # Recreate projects table
    create_table :projects do |t|
      t.string :title
      t.string :description
      t.boolean :inbox, default: false, null: false
      t.integer :position
      t.integer :prioritization_method, default: 0, null: false
      t.integer :user_id
      t.timestamps
    end
    add_index :projects, :user_id
    add_index :projects, :position
    add_index :projects, [:user_id, :position], unique: true
    add_index :projects, [:user_id, :inbox], unique: true, where: "(inbox = true)", name: "index_projects_on_user_id_inbox_unique"
    add_foreign_key :projects, :users

    # Recreate task_lists table
    create_table :task_lists do |t|
      t.string :title
      t.integer :position
      t.bigint :project_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :task_lists, :position
    add_index :task_lists, :project_id
    add_index :task_lists, :user_id
    add_foreign_key :task_lists, :projects
    add_foreign_key :task_lists, :users

    # Recreate tags table
    create_table :tags do |t|
      t.string :name, null: false
      t.string :color, default: "gray", null: false
      t.integer :position
      t.bigint :project_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :tags, :project_id
    add_index :tags, :user_id
    add_index :tags, [:project_id, :name], unique: true
    add_foreign_key :tags, :projects
    add_foreign_key :tags, :users

    # Recreate task_tags table
    create_table :task_tags do |t|
      t.bigint :task_id, null: false
      t.bigint :tag_id, null: false
      t.timestamps
    end
    add_index :task_tags, :task_id
    add_index :task_tags, :tag_id
    add_index :task_tags, [:task_id, :tag_id], unique: true
    add_foreign_key :task_tags, :tasks
    add_foreign_key :task_tags, :tags

    # Re-add columns to tasks
    add_column :tasks, :project_id, :integer
    add_column :tasks, :task_list_id, :bigint
    add_index :tasks, :project_id
    add_index :tasks, :task_list_id
    add_foreign_key :tasks, :projects
    add_foreign_key :tasks, :task_lists
  end
end
