class AddSessionContinuationToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :agent_session_key, :string
    add_column :tasks, :context_usage_percent, :integer
  end
end
