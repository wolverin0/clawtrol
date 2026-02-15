class EnsureDeepSummaryFieldsOnSavedLinks < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:saved_links, :deep_summary)
      add_column :saved_links, :deep_summary, :boolean, default: false, null: false
    end

    unless column_exists?(:saved_links, :summary_file_path)
      add_column :saved_links, :summary_file_path, :string
    end

    # Ensure expected constraints/defaults
    if column_exists?(:saved_links, :deep_summary)
      change_column_default :saved_links, :deep_summary, from: nil, to: false
      execute "UPDATE saved_links SET deep_summary = FALSE WHERE deep_summary IS NULL"
      change_column_null :saved_links, :deep_summary, false
    end
  end
end
