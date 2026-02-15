# frozen_string_literal: true

class CreateCostSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :cost_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.string :period, null: false, default: "daily" # daily, weekly, monthly
      t.date :snapshot_date, null: false
      t.decimal :total_cost, precision: 12, scale: 6, default: 0.0, null: false
      t.integer :total_input_tokens, default: 0, null: false
      t.integer :total_output_tokens, default: 0, null: false
      t.integer :api_calls, default: 0, null: false
      t.jsonb :cost_by_model, default: {}, null: false       # { "opus" => 1.23, "codex" => 0.45 }
      t.jsonb :cost_by_source, default: {}, null: false      # { "cron:abc" => 0.5, "task:123" => 0.8 }
      t.jsonb :tokens_by_model, default: {}, null: false     # { "opus" => { "input" => 100, "output" => 50 } }
      t.decimal :budget_limit, precision: 10, scale: 2       # user-set budget for this period
      t.boolean :budget_exceeded, default: false, null: false
      t.timestamps
    end

    add_index :cost_snapshots, %i[user_id period snapshot_date], unique: true, name: "idx_cost_snapshots_user_period_date"
    add_index :cost_snapshots, :snapshot_date
    add_index :cost_snapshots, :budget_exceeded
  end
end
