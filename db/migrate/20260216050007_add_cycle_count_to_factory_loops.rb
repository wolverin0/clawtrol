class AddCycleCountToFactoryLoops < ActiveRecord::Migration[8.1]
  def change
    add_column :factory_loops, :cycle_count, :integer, default: 0
  end
end
