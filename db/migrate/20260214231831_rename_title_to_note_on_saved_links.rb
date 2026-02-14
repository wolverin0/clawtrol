class RenameTitleToNoteOnSavedLinks < ActiveRecord::Migration[8.1]
  def change
    rename_column :saved_links, :title, :note
  end
end
