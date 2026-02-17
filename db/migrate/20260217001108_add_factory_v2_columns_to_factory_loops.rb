class AddFactoryV2ColumnsToFactoryLoops < ActiveRecord::Migration[8.1]
  def change
    add_column :factory_loops, :idle_policy, :string, default: "pause"
    add_column :factory_loops, :workspace_path, :string
    add_column :factory_loops, :work_branch, :string, default: "factory/auto"
    add_column :factory_loops, :protected_branches, :jsonb, default: ["main", "master"]
    add_column :factory_loops, :db_url_override, :string
    add_column :factory_loops, :backlog_path, :string, default: "FACTORY_BACKLOG.md"
    add_column :factory_loops, :findings_path, :string, default: "FACTORY_FINDINGS.md"
    add_column :factory_loops, :max_session_minutes, :integer, default: 240
    add_column :factory_loops, :confidence_threshold, :integer, default: 90
    add_column :factory_loops, :max_findings_per_run, :integer, default: 5
  end
end
