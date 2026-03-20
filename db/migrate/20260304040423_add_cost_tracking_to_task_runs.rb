class AddCostTrackingToTaskRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :task_runs, :cost_usd, :decimal, precision: 12, scale: 6
    add_column :task_runs, :input_tokens, :integer
    add_column :task_runs, :output_tokens, :integer
    add_column :task_runs, :model_name, :string
  end
end
