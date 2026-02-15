class AddDeepResearchToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :deep_research, :boolean, default: false, null: false
  end
end
