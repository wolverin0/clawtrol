class AddCycleCountToFactoryLoops < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:factory_loops, :cycle_count)

    add_column :factory_loops, :cycle_count, :integer, default: 0
  end
end
