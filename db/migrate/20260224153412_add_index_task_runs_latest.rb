# frozen_string_literal: true

class AddIndexTaskRunsLatest < ActiveRecord::Migration[8.1]
  def change
    add_index :task_runs, [:task_id, :created_at], order: { created_at: :desc }, name: "idx_task_runs_latest_per_task"
  end
end
