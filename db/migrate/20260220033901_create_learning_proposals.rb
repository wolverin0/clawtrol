class CreateLearningProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_proposals do |t|
      t.string :title, null: false
      t.string :proposed_by, default: "self-audit"
      t.string :target_file, null: false
      t.text :current_content
      t.text :proposed_content, null: false
      t.text :diff_preview
      t.integer :status, default: 0
      t.string :reason
      t.bigint :user_id

      t.timestamps
    end

    add_index :learning_proposals, :user_id
  end
end
