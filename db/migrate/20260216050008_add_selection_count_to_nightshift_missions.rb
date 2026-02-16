class AddSelectionCountToNightshiftMissions < ActiveRecord::Migration[8.1]
  def change
    add_column :nightshift_missions, :selection_count, :integer, default: 0
  end
end
