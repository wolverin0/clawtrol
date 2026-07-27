# frozen_string_literal: true

class AddOrchestrationControlPlane < ActiveRecord::Migration[8.1]
  def change
    create_table :orchestration_sources do |t|
      t.references :user, null: false, foreign_key: true
      t.string :profile, null: false
      t.string :status, null: false, default: "stale"
      t.datetime :last_seen_at
      t.datetime :generated_at
      t.text :last_error
      t.jsonb :health, null: false, default: {}
      t.jsonb :panes, null: false, default: []
      t.timestamps
    end
    add_index :orchestration_sources, %i[user_id profile], unique: true
    add_index :orchestration_sources, :last_seen_at

    create_table :orchestration_intents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :orchestration_source, null: false, foreign_key: true
      t.references :task, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :payload, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.datetime :processed_at
      t.timestamps
    end
    add_index :orchestration_intents,
      %i[orchestration_source_id status id],
      name: "idx_orchestration_intents_source_status"

    add_index :tasks, %i[user_id origin_session_key],
      unique: true,
      name: "idx_tasks_user_wezbridge_origin_key",
      where: "origin_session_key LIKE 'wezbridge:%'"
  end
end
