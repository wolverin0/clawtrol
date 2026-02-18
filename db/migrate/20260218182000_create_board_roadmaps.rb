# frozen_string_literal: true

class CreateBoardRoadmaps < ActiveRecord::Migration[8.1]
  def change
    create_table :board_roadmaps do |t|
      t.references :board, null: false, foreign_key: true, index: { unique: true }
      t.text :body, null: false, default: ""
      t.jsonb :metadata, null: false, default: {}
      t.datetime :last_generated_at
      t.integer :last_generated_count, null: false, default: 0

      t.timestamps
    end
  end
end
