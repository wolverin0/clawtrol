class AddSelectionCountToNightshiftMissions < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:nightshift_missions, :selection_count)

    add_column :nightshift_missions, :selection_count, :integer, default: 0
  end
end
