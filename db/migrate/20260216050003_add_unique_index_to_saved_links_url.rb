# frozen_string_literal: true

class AddUniqueIndexToSavedLinksUrl < ActiveRecord::Migration[8.0]
  def up
    # Remove duplicate saved_links (keep the most recent per user+url)
    execute <<~SQL
      DELETE FROM saved_links
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM saved_links
        GROUP BY user_id, url
      )
    SQL

    add_index :saved_links, [:user_id, :url], unique: true, name: "index_saved_links_on_user_id_and_url", if_not_exists: true
  end

  def down
    remove_index :saved_links, name: "index_saved_links_on_user_id_and_url", if_exists: true
  end
end
