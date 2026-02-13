class FixNightshiftSelectionMissionFk < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE nightshift_selections
      SET nightshift_mission_id = mission_id
      WHERE nightshift_mission_id IS NULL
    SQL

    if index_exists?(:nightshift_selections, [:mission_id, :scheduled_date], name: "index_nightshift_selections_on_mission_id_and_scheduled_date")
      remove_index :nightshift_selections, name: "index_nightshift_selections_on_mission_id_and_scheduled_date"
    end

    add_index :nightshift_selections, [:nightshift_mission_id, :scheduled_date],
      unique: true,
      name: "index_nightshift_selections_on_mission_and_scheduled_date"

    remove_column :nightshift_selections, :mission_id, :integer

    change_column_null :nightshift_selections, :nightshift_mission_id, false
  end

  def down
    add_column :nightshift_selections, :mission_id, :integer

    execute <<~SQL
      UPDATE nightshift_selections
      SET mission_id = nightshift_mission_id
      WHERE mission_id IS NULL
    SQL

    change_column_null :nightshift_selections, :mission_id, false

    if index_exists?(:nightshift_selections, [:nightshift_mission_id, :scheduled_date], name: "index_nightshift_selections_on_mission_and_scheduled_date")
      remove_index :nightshift_selections, name: "index_nightshift_selections_on_mission_and_scheduled_date"
    end

    add_index :nightshift_selections, [:mission_id, :scheduled_date],
      unique: true,
      name: "index_nightshift_selections_on_mission_id_and_scheduled_date"

    change_column_null :nightshift_selections, :nightshift_mission_id, true
  end
end
