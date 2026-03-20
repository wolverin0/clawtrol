class AddDecisionLoopToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :consecutive_failures, :integer, default: 0, null: false
    add_column :tasks, :needs_decision, :boolean, default: false, null: false
    add_index :tasks, :needs_decision, where: "needs_decision = true"
  end
end
