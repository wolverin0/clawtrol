class ExpandFactoryLoopsAndCycleLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :factory_loops, :idle_policy, :string, default: "pause" unless column_exists?(:factory_loops, :idle_policy)
    add_column :factory_loops, :workspace_path, :string unless column_exists?(:factory_loops, :workspace_path)
    add_column :factory_loops, :work_branch, :string, default: "factory/auto" unless column_exists?(:factory_loops, :work_branch)
    add_column :factory_loops, :protected_branches, :jsonb, default: ["main", "master"] unless column_exists?(:factory_loops, :protected_branches)
    add_column :factory_loops, :db_url_override, :string unless column_exists?(:factory_loops, :db_url_override)
    add_column :factory_loops, :backlog_path, :string, default: "FACTORY_BACKLOG.md" unless column_exists?(:factory_loops, :backlog_path)
    add_column :factory_loops, :findings_path, :string, default: "FACTORY_FINDINGS.md" unless column_exists?(:factory_loops, :findings_path)
    add_column :factory_loops, :max_session_minutes, :integer, default: 240 unless column_exists?(:factory_loops, :max_session_minutes)
    add_column :factory_loops, :confidence_threshold, :integer, default: 90 unless column_exists?(:factory_loops, :confidence_threshold)
    add_column :factory_loops, :max_findings_per_run, :integer, default: 5 unless column_exists?(:factory_loops, :max_findings_per_run)

    add_column :factory_cycle_logs, :backlog_item, :string unless column_exists?(:factory_cycle_logs, :backlog_item)
    add_column :factory_cycle_logs, :agent_name, :string unless column_exists?(:factory_cycle_logs, :agent_name)
    add_column :factory_cycle_logs, :trigger, :string, default: "backlog" unless column_exists?(:factory_cycle_logs, :trigger)
    add_column :factory_cycle_logs, :commits, :jsonb, default: [] unless column_exists?(:factory_cycle_logs, :commits)
    add_column :factory_cycle_logs, :files_changed, :integer, default: 0 unless column_exists?(:factory_cycle_logs, :files_changed)
    add_column :factory_cycle_logs, :tests_run, :integer unless column_exists?(:factory_cycle_logs, :tests_run)
    add_column :factory_cycle_logs, :tests_passed, :integer unless column_exists?(:factory_cycle_logs, :tests_passed)
    add_column :factory_cycle_logs, :tests_failed, :integer unless column_exists?(:factory_cycle_logs, :tests_failed)
  end
end
