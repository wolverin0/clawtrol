class AddFactoryEngineColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :factory_loops, :consecutive_failures, :integer, default: 0, null: false
    add_column :factory_cycle_logs, :openclaw_session_key, :string
  end
end
