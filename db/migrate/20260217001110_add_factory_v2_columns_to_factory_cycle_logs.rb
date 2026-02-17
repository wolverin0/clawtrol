class AddFactoryV2ColumnsToFactoryCycleLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :factory_cycle_logs, :backlog_item, :string
    add_column :factory_cycle_logs, :agent_name, :string
    add_column :factory_cycle_logs, :trigger, :string, default: "backlog"
    add_column :factory_cycle_logs, :commits, :jsonb, default: []
    add_column :factory_cycle_logs, :files_changed, :integer, default: 0
    add_column :factory_cycle_logs, :tests_run, :integer
    add_column :factory_cycle_logs, :tests_passed, :integer
    add_column :factory_cycle_logs, :tests_failed, :integer
  end
end
