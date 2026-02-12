class RemoveUrlFromProjects < ActiveRecord::Migration[8.1]
  def change
    remove_column :projects, :url, :string
  end
end
