# frozen_string_literal: true

class CreateAgentMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_messages do |t|
      t.references :task, null: false, foreign_key: { on_delete: :cascade }
      t.references :source_task, null: true, foreign_key: { to_table: :tasks, on_delete: :nullify }
      t.string :direction, null: false, default: "incoming"  # incoming (from another agent) or outgoing (to another agent)
      t.string :sender_model, limit: 100                      # e.g. "opus", "codex", "gemini"
      t.string :sender_session_id, limit: 200                 # openclaw session id
      t.string :sender_name, limit: 100                       # agent persona name
      t.text :content, null: false                             # the actual message/output
      t.text :summary                                          # optional short summary
      t.string :message_type, null: false, default: "output"   # output, handoff, feedback, error
      t.jsonb :metadata, null: false, default: {}              # extra context (run_id, phase, etc.)
      t.datetime :created_at, null: false
    end

    add_index :agent_messages, [:task_id, :created_at], name: "idx_agent_messages_task_timeline"
    add_index :agent_messages, :source_task_id, where: "source_task_id IS NOT NULL", name: "idx_agent_messages_source_task"
    add_index :agent_messages, :direction
  end
end
