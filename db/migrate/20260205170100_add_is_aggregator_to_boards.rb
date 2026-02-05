class AddIsAggregatorToBoards < ActiveRecord::Migration[8.1]
  def change
    # Add flag for boards that aggregate tasks from all boards
    add_column :boards, :is_aggregator, :boolean, default: false, null: false
    add_index :boards, :is_aggregator, where: "is_aggregator = true"
  end
end
