class AddAudioSummaryToSavedLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_links, :audio_summary, :boolean, default: false
    add_column :saved_links, :audio_file_path, :string
  end
end
