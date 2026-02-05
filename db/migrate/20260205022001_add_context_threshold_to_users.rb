class AddContextThresholdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :context_threshold_percent, :integer, default: 70, null: false
  end
end
