# frozen_string_literal: true

class CreateBoardFileRefs < ActiveRecord::Migration[8.0]
  def change
    create_table :board_file_refs do |t|
      t.references :board, null: false, foreign_key: true
      t.string :path, null: false
      t.string :label
      t.string :category, null: false, default: "general"
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :board_file_refs, [:board_id, :path], unique: true
    add_index :board_file_refs, [:board_id, :category, :position]
  end
end
