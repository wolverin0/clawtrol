class AddUserIdToNightshiftMissionsAndFactoryLoops < ActiveRecord::Migration[8.0]
  def change
    add_reference :nightshift_missions, :user, null: true, foreign_key: true
    add_reference :factory_loops, :user, null: true, foreign_key: true
  end
end
