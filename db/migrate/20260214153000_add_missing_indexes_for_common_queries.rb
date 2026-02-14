class AddMissingIndexesForCommonQueries < ActiveRecord::Migration[8.0]
  def change
    add_index :nightshift_selections, [:scheduled_date, :enabled],
              name: "index_nightshift_selections_on_date_enabled"
    add_index :saved_links, [:user_id, :created_at],
              name: "index_saved_links_on_user_id_and_created_at",
              order: { created_at: :desc }
    add_index :saved_links, :status,
              name: "index_saved_links_on_status"
  end
end
