class AddInboxToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :inbox, :boolean, default: false, null: false
    add_index :projects, [:user_id, :inbox], unique: true, where: "inbox = true", name: "index_projects_on_user_id_inbox_unique"
  end
end
