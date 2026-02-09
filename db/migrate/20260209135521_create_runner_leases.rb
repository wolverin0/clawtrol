class CreateRunnerLeases < ActiveRecord::Migration[8.1]
  def change
    create_table :runner_leases do |t|
      t.references :task, null: false, foreign_key: true

      t.string :agent_name
      t.string :source, null: false, default: "auto_runner"

      t.string :lease_token, null: false

      t.datetime :started_at, null: false
      t.datetime :last_heartbeat_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :released_at

      t.timestamps
    end

    add_index :runner_leases, :lease_token, unique: true
    add_index :runner_leases, :expires_at
    add_index :runner_leases, :task_id, unique: true, where: "released_at IS NULL", name: "index_runner_leases_on_task_id_active"
  end
end
