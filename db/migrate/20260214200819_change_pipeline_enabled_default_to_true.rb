class ChangePipelineEnabledDefaultToTrue < ActiveRecord::Migration[8.1]
  def change
    change_column_default :tasks, :pipeline_enabled, from: false, to: true
  end
end
