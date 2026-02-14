class CreateAgentTranscripts < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_transcripts do |t|
      t.references :task, null: true, foreign_key: true, index: true
      t.references :task_run, null: true, foreign_key: true
      t.string :session_id, null: false, index: { unique: true }
      t.string :session_key
      t.string :model
      t.text :prompt_text
      t.text :output_text
      t.integer :total_tokens
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :message_count
      t.integer :tool_call_count
      t.float :cost_usd
      t.integer :runtime_seconds
      t.string :status, default: "captured"
      t.text :raw_jsonl
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
