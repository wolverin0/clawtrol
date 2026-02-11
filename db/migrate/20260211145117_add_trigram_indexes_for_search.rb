class AddTrigramIndexesForSearch < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    add_index :tasks, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_tasks_on_name_trigram"
    add_index :tasks, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_tasks_on_description_trigram"
  end
end
