class ReplaceSavedLinkAudioWithDeepSummary < ActiveRecord::Migration[8.1]
  def change
    rename_column :saved_links, :audio_summary, :deep_summary
    rename_column :saved_links, :audio_file_path, :summary_file_path
  end
end
