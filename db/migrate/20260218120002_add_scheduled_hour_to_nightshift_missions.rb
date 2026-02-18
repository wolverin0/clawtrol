class AddScheduledHourToNightshiftMissions < ActiveRecord::Migration[8.1]
  def change
    add_column :nightshift_missions, :scheduled_hour, :integer
  end
end
