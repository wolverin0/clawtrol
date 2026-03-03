# frozen_string_literal: true

class CreateLearningEffectiveness < ActiveRecord::Migration[7.1]
  def change
    create_table :learning_effectiveness do |t|
      t.references :task, null: false, foreign_key: true
      t.references :task_run, foreign_key: true
      t.string :learning_entry_id, null: false
      t.string :learning_title, null: false
      t.boolean :task_succeeded, null: false, default: false
      t.boolean :needs_follow_up, null: false, default: false
      t.string :recommended_action
      t.float :effectiveness_score
      t.datetime :surfaced_at, null: false
      t.timestamps
    end

    add_index :learning_effectiveness, :learning_entry_id
    add_index :learning_effectiveness, :task_succeeded
    add_index :learning_effectiveness, [:learning_entry_id, :task_succeeded],
              name: "idx_learning_effectiveness_entry_success"
  end
end
